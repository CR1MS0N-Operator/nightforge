#!/bin/bash
# Security Status Check
# Verify hardening configuration

echo "🔒 Security Status Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Firewall Status
echo ""
echo "[1] Firewall Status (ufw):"
if command -v ufw &> /dev/null; then
    sudo ufw status verbose | sed 's/^/  /'
else
    echo "  ❌ ufw not installed"
fi

# SSH Status
echo ""
echo "[2] SSH Status:"
if systemctl is-active --quiet sshd; then
    echo "  ✓ SSH running"
    echo ""
    echo "  Configuration:"
    sudo grep -E "^(Port|PermitRootLogin|PasswordAuthentication|AllowUsers)" /etc/ssh/sshd_config.d/hardening.conf 2>/dev/null | sed 's/^/    /'
else
    echo "  ℹ️  SSH not running (configured but disabled)"
fi

# Fail2ban Status
echo ""
echo "[3] Fail2ban Status:"
if systemctl is-active --quiet fail2ban; then
    echo "  ✓ Fail2ban running"
    sudo fail2ban-client status 2>/dev/null | sed 's/^/  /'
else
    echo "  ⚠️  Fail2ban not running"
fi

# Open Ports
echo ""
echo "[4] Open Ports:"
sudo ss -tulpn | grep LISTEN | awk '{print "  "$5" → "$7}' | sort -u

# Recent Failed Logins
echo ""
echo "[5] Recent Failed Login Attempts (last 24h):"
FAILED=$(sudo journalctl --since "24 hours ago" 2>/dev/null | grep -ciE "failed.*(auth|login|ssh)")
echo "  Count: $FAILED"
if [ "$FAILED" -gt 0 ]; then
    sudo journalctl --since "24 hours ago" 2>/dev/null | grep -i "failed" | grep -i "auth\|login\|ssh" | tail -5 | sed 's/^/  /'
fi

# Fail2ban Bans
echo ""
echo "[6] Fail2ban Active Bans:"
if systemctl is-active --quiet fail2ban; then
    BANNED=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
    echo "  Currently banned IPs: ${BANNED:-0}"
fi

# Network Security
echo ""
echo "[7] Network Security Settings:"
echo "  SYN Cookies: $(sysctl -n net.ipv4.tcp_syncookies)"
echo "  IP Forwarding: $(sysctl -n net.ipv4.ip_forward)"
echo "  ICMP Redirects: $(sysctl -n net.ipv4.conf.all.accept_redirects)"
echo "  Reverse Path Filter: $(sysctl -n net.ipv4.conf.all.rp_filter)"

# Filesystem Security
echo ""
echo "[8] Filesystem Security:"
echo "  /tmp mount options:"
mount | grep " /tmp " | awk '{print "    "$6}' || echo "    Default (not secured)"
echo "  Home directory permissions:"
stat -c '%A' "$HOME" | awk '{print "    "$1}'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Security check complete"
