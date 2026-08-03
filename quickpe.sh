#!/bin/sh
# Simple PrivEsc checks + GTFOBins hints - restricted shell friendly

echo "========== 1. sudo -l =========="
sudo -l 2>/dev/null || echo "[-] sudo not available or permission denied"
echo

echo "========== 2. SUID binaries =========="
SUIDS=$(find / -perm -u=s -type f 2>/dev/null)
echo "$SUIDS"
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
