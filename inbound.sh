#!/bin/bash

# Clear screen
clear

# --- Banner Section ---
echo "------------------------------------------------------------"
echo -e "\e[1;36m"
echo "   __   ___   __   __  "
echo "  /_ | / _ \ /_ | /_ | "
echo "   | || | | | | |  | | "
echo "   | || |_| | | |  | | "
echo "   |_| \___/  |_|  |_| "
echo "                       "
echo -e "\e[0m"
echo "   1011 Inbound Setup (Stable Protocols)"
echo "------------------------------------------------------------"
echo -e "\e[1;33m  Installing Protocols:\e[0m"
echo "  🔹 VLESS (Reality, WS TLS, TCP, gRPC)"
echo "  🔹 VMess (WS TLS & TCP)"
echo "  🔹 Trojan (TLS & TCP)"
echo "  🔹 Shadowsocks"
echo "--------------------------------------------------"

# --- Check Domain ---
DOMAIN=$(ls -1 /var/lib/marzban/certs/ 2>/dev/null | head -n 1)
if [ -z "$DOMAIN" ]; then
    echo -e "\e[1;31m❌ Error: Domain folder not found. Run 1011 install script first.\e[0m"
    exit 1
else
    echo -e "\e[1;32m✅ Domain found: $DOMAIN\e[0m"
fi

echo "🔑 Generating Keys..."

# --- Get Reality Keys ---
KEYS=$(docker exec marzban-marzban-1 xray x25519 2>/dev/null || docker exec marzban-1 xray x25519 2>/dev/null)

if [ -z "$KEYS" ]; then
    echo "🌐 Downloading xray core directly..."
    apt update && apt install unzip -y &>/dev/null
    curl -L -o /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip &>/dev/null
    unzip -o /tmp/xray.zip xray -d /tmp/ &>/dev/null
    chmod +x /tmp/xray
    KEYS=$(/tmp/xray x25519)
fi

PRIV=$(echo "$KEYS" | grep "Private key" | cut -d ' ' -f 3)
PUB=$(echo "$KEYS" | grep "Public key" | cut -d ' ' -f 3)
SID=$(openssl rand -hex 4)

if [ -z "$PRIV" ]; then
    echo -e "\e[1;31m❌ Error: Failed to generate Reality Keys.\e[0m"
    exit 1
fi

echo -e "\e[1;32m✅ Keys Generated Successfully.\e[0m"

# --- Create xray_config.json ---
cat <<EOF > /var/lib/marzban/xray_config.json
{
    "log": { "loglevel": "warning" },
    "routing": {
        "rules": [ { "type": "field", "ip": ["geoip:private"], "outboundTag": "BLOCK" } ]
    },
    "inbounds": [
        {
            "tag": "VLESS WS TLS",
            "listen": "0.0.0.0",
            "port": 2083,
            "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": {
                "network": "ws", "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "/var/lib/marzban/certs/$DOMAIN/fullchain.pem",
                        "keyFile": "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
                    }]
                },
                "wsSettings": { "path": "/vless" }
            }
        },
        {
            "tag": "VLESS REALITY",
            "listen": "0.0.0.0",
            "port": 443,
            "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": {
                "network": "tcp", "security": "reality",
                "realitySettings": {
                    "show": false, "dest": "www.cloudflare.com:443", "xver": 0,
                    "serverNames": ["www.cloudflare.com", "$DOMAIN"],
                    "privateKey": "$PRIV",
                    "publicKey": "$PUB",
                    "shortIds": ["$SID"]
                }
            },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
        },
        {
            "tag": "VMess WS TLS",
            "listen": "0.0.0.0",
            "port": 8443,
            "protocol": "vmess",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "ws", "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "/var/lib/marzban/certs/$DOMAIN/fullchain.pem",
                        "keyFile": "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
                    }]
                },
                "wsSettings": { "path": "/vmess" }
            }
        },
        {
            "tag": "Trojan TLS",
            "listen": "0.0.0.0",
            "port": 2053,
            "protocol": "trojan",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "tcp", "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "/var/lib/marzban/certs/$DOMAIN/fullchain.pem",
                        "keyFile": "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
                    }]
                }
            }
        },
        {
            "tag": "VLESS TCP",
            "listen": "0.0.0.0",
            "port": 9850,
            "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": { "network": "tcp", "security": "none" },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
        },
        {
            "tag": "VMESS TCP",
            "listen": "0.0.0.0",
            "port": 4427,
            "protocol": "vmess",
            "settings": { "clients": [] },
            "streamSettings": { "network": "tcp", "security": "none" },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
        },
        {
            "tag": "TROJAN TCP",
            "listen": "0.0.0.0",
            "port": 9094,
            "protocol": "trojan",
            "settings": { "clients": [] },
            "streamSettings": { "network": "tcp", "security": "none" },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
        },
        {
            "tag": "Shadowsocks TCP",
            "listen": "0.0.0.0",
            "port": 1080,
            "protocol": "shadowsocks",
            "settings": { "clients": [], "network": "tcp,udp" }
        },
        {
            "tag": "VLESS gRPC",
            "listen": "0.0.0.0",
            "port": 2087,
            "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": {
                "network": "grpc",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "/var/lib/marzban/certs/$DOMAIN/fullchain.pem",
                        "keyFile": "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
                    }]
                },
                "grpcSettings": { "serviceName": "vless-grpc" }
            }
        }
    ],
    "outbounds": [
        { "protocol": "freedom", "tag": "DIRECT" },
        { "protocol": "blackhole", "tag": "BLOCK" }
    ]
}
EOF

echo "✅ JSON File Updated with Stable Protocols (Removed deprecated H2/QUIC)."
marzban restart

# Cleanup
rm -rf /tmp/xray.zip /tmp/xray 2>/dev/null

echo "--------------------------------------------------"
echo -e "\e[1;32m🔥 1011 Stable Inbound Setup Complete! 🔥\e[0m"
echo "--------------------------------------------------"
