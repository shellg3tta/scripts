#!/bin/bash
# ============================================================
# Efficient Web Recon Playbook for *.domain scope
# Usage: ./web-recon.sh pentest.test
# ============================================================

set -euo pipefail

# -------------------- CONFIG --------------------
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <domain>"
  echo "Example: $0 pentest.test"
  exit 1
fi

# Wordlists (adjust paths if needed)
DIR_WORDLIST="/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt"
COMMON_WORDLIST="/usr/share/seclists/Discovery/Web-Content/common.txt"
# ------------------------------------------------

# Create directory structure
mkdir -p recon/{subs,live,crawl,dirs,params,leads,screens}
cd recon

echo "[*] Target: $TARGET"
echo "[*] Output directory: $(pwd)"
echo

# ============================================================
# PHASE 1: Subdomain Enumeration (Passive)
# ============================================================
echo "[+] Phase 1: Subdomain Enumeration"

subfinder -d "$TARGET" -all -silent -o subs/subfinder.txt &
amass enum -passive -d "$TARGET" -silent -o subs/amass.txt 2>/dev/null &
assetfinder --subs-only "$TARGET" > subs/assetfinder.txt &
curl -s "https://crt.sh/?q=%25.$TARGET&output=json" | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' | sort -u > subs/crtsh.txt &

wait

cat subs/*.txt 2>/dev/null | sort -u > subs/all_subs.txt
echo "[+] Found $(wc -l < subs/all_subs.txt) unique subdomains"
echo

# ============================================================
# PHASE 2: Live Host Discovery + Fingerprinting
# ============================================================
echo "[+] Phase 2: Live Host Discovery (httpx)"

cat subs/all_subs.txt | httpx -silent -threads 100 \
  -status-code -title -tech-detect -web-server -content-length \
  -follow-redirects -o live/httpx_full.txt

# Extract clean live URLs
cut -d' ' -f1 live/httpx_full.txt | sort -u > live/live_urls.txt

echo "[+] Live hosts: $(wc -l < live/live_urls.txt)"
echo "[+] Interesting status codes:"
grep -E "\[(200|301|302|401|403|500)\]" live/httpx_full.txt | head -20 || true
echo

# ============================================================
# PHASE 3: Spider / Crawl (Katana + historical)
# ============================================================
echo "[+] Phase 3: Crawling with Katana"

katana -list live/live_urls.txt -d 3 -jc -kf all -c 20 -silent -o crawl/katana.txt

# Historical sources (quick)
echo "[*] Pulling historical URLs..."
cat live/live_urls.txt | gau --subs 2>/dev/null | tee crawl/gau.txt >/dev/null &
cat live/live_urls.txt | waybackurls 2>/dev/null | tee crawl/wayback.txt >/dev/null &
wait

# Combine and extract useful data
cat crawl/*.txt 2>/dev/null | grep -Eo 'https?://[^ ]+' | sort -u > crawl/all_urls.txt

# Extract paths and parameters
cat crawl/all_urls.txt | unfurl paths 2>/dev/null | sort -u > crawl/paths.txt
cat crawl/all_urls.txt | unfurl keys 2>/dev/null | sort -u > crawl/params.txt
cat crawl/all_urls.txt | grep '?' | sort -u > crawl/urls_with_params.txt

echo "[+] Crawled URLs: $(wc -l < crawl/all_urls.txt)"
echo "[+] Unique paths: $(wc -l < crawl/paths.txt)"
echo "[+] Unique parameters: $(wc -l < crawl/params.txt)"
echo

# ============================================================
# PHASE 4: Directory Busting (dirsearch) - Priority hosts
# ============================================================
echo "[+] Phase 4: Directory Busting with dirsearch"
echo "[*] Running on first 8 live hosts (edit script to change)"

# Take top live hosts (you can edit this list later)
head -8 live/live_urls.txt > live/priority_hosts.txt

while read -r url; do
  safe_name=$(echo "$url" | sed 's|https\?://||; s|/|_|g; s|:|_|g')
  echo "[*] dirsearch → $url"
  dirsearch -u "$url" \
    -e php,aspx,asp,jsp,html,js,txt,bak,old,zip,tar,gz,sql,log,conf,config,xml,json \
    -w "$DIR_WORDLIST" \
    -t 30 -r -R 2 \
    -x 404,429 \
    --exclude-subdirs=images/,css/,js/,static/,assets/,img/,fonts/ \
    --format plain \
    -o "dirs/dirsearch_${safe_name}.txt" 2>/dev/null || true
done < live/priority_hosts.txt

echo "[+] Directory scans complete"
echo

# ============================================================
# PHASE 5: Extract Interesting Leads
# ============================================================
echo "[+] Phase 5: Extracting interesting leads"

# Interesting endpoints from crawl + dirsearch
cat crawl/paths.txt dirs/*.txt 2>/dev/null | \
  grep -Ei 'admin|api|login|upload|config|backup|debug|test|dev|staging|swagger|graphql|\.json|\.xml|\.bak|\.old|\.sql|\.zip|\.env|\.git' | \
  sort -u > leads/interesting_endpoints.txt

# Parameters that look juicy
cat crawl/params.txt | \
  grep -Ei 'id|user|file|path|page|url|redirect|next|data|token|key|pass|cmd|exec|query|search' | \
  sort -u > leads/interesting_params.txt

echo "[+] Interesting endpoints: $(wc -l < leads/interesting_endpoints.txt)"
echo "[+] Interesting parameters: $(wc -l < leads/interesting_params.txt)"
echo
echo "=== Quick leads preview ==="
head -15 leads/interesting_endpoints.txt || true
echo

# ============================================================
# DONE
# ============================================================
echo "[✓] Recon finished!"
echo
echo "Key files:"
echo "  Live hosts:          live/live_urls.txt"
echo "  Full httpx data:     live/httpx_full.txt"
echo "  All crawled URLs:    crawl/all_urls.txt"
echo "  Paths:               crawl/paths.txt"
echo "  Parameters:          crawl/params.txt"
echo "  Dirsearch results:   dirs/"
echo "  Interesting leads:   leads/"
echo
echo "Next steps ideas:"
echo "  • Feed live/live_urls.txt into Nuclei"
echo "  • Run Arjun on crawl/urls_with_params.txt"
echo "  • ffuf interesting endpoints with custom wordlists"
echo "  • Manual review of leads/interesting_endpoints.txt"
echo
