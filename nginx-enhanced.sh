#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NGINX_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
PUBLIC_IP="ip"
LOG_FILE="/var/log/nginx-proxy.log"
CERTBOT_EMAIL="your-email@example.com"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script with sudo.${NC}"
    exit 1
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

install_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    local deps=(nginx certbot python3-certbot-nginx curl ss)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing missing dependencies: ${missing[*]}${NC}"
        sudo apt update && sudo apt install -y "${missing[@]}"
    else
        echo -e "${GREEN}All dependencies are installed.${NC}"
    fi
}

validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}Invalid port: $port. Must be between 1-65535.${NC}"
        exit 1
    fi
}

validate_domain() {
    local domain=$1
    if ! [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Invalid domain name: $domain.${NC}"
        exit 1
    fi
}

check_port() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        echo -e "${RED}Port $port is already in use.${NC}"
        exit 1
    fi
}

check_local_service() {
    local port=$1
    if curl -s "http://127.0.0.1:$port" >/dev/null 2>&1; then
        log "Local service on 127.0.0.1:$port is running."
    else
        echo -e "${YELLOW}Warning: No response from 127.0.0.1:$port.${NC}"
        log "No response from 127.0.0.1:$port"
    fi
}

add_proxy() {
    local public_port=$1
    local local_port=$2
    local domain=${3:-$PUBLIC_IP}
    local ssl_flag=$4

    validate_port "$public_port"
    validate_port "$local_port"
    [[ "$domain" != "$PUBLIC_IP" ]] && validate_domain "$domain"
    check_port "$public_port"
    check_local_service "$local_port"

    local config_name="port-$public_port"
    local listen="listen $public_port;"
    local ssl_config=""
    local scheme="http"

    if [ "$ssl_flag" == "ssl" ]; then
        if [ "$domain" == "$PUBLIC_IP" ]; then
            echo -e "${RED}SSL requires a domain, not an IP.${NC}"
            exit 1
        fi

        scheme="https"
        listen="listen $public_port ssl;"
        ssl_config="
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;"

        echo -e "${GREEN}Requesting SSL certificate for $domain...${NC}"
        certbot certonly --nginx -d "$domain" --non-interactive --agree-tos --email "$CERTBOT_EMAIL"
    fi

    cat > "$NGINX_DIR/$config_name" << EOF
server {
    $listen
    server_name $domain;
    autoindex off;
    $ssl_config

    location / {
        proxy_pass http://127.0.0.1:$local_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    ln -sf "$NGINX_DIR/$config_name" "$NGINX_ENABLED_DIR/$config_name"
    systemctl reload nginx

    echo -e "${GREEN}Proxy added: $scheme://$domain:$public_port -> 127.0.0.1:$local_port${NC}"
    log "Proxy added: $scheme://$domain:$public_port -> 127.0.0.1:$local_port"
}

remove_proxy() {
    local public_port=$1
    validate_port "$public_port"

    local config_name="port-$public_port"
    rm -f "$NGINX_DIR/$config_name" "$NGINX_ENABLED_DIR/$config_name"
    systemctl reload nginx

    echo -e "${GREEN}Removed proxy on port $public_port.${NC}"
    log "Removed proxy on port $public_port."
}

list_proxies() {
    echo "Active Proxies:"
    for config in "$NGINX_ENABLED_DIR"/*; do
        local name=$(basename "$config")
        local port=$(echo "$name" | sed 's/port-//')
        echo -e "${GREEN}Proxy on port $port${NC}"
    done
}

renew_ssl() {
    echo -e "${GREEN}Renewing SSL certificates...${NC}"
    certbot renew
    systemctl reload nginx
}

cleanup() {
    echo -e "${GREEN}Removing all proxy configurations...${NC}"
    rm -f "$NGINX_DIR"/port-* "$NGINX_ENABLED_DIR"/port-*
    systemctl reload nginx
    echo -e "${GREEN}All proxies removed.${NC}"
}

interactive_mode() {
    echo -e "${YELLOW}Welcome to Interactive Mode!${NC}"
    echo "Choose an action:"
    select action in "Add Proxy" "Remove Proxy" "List Proxies" "Renew SSL" "Exit"; do
        case $action in
            "Add Proxy")
                read -p "Public Port: " public_port
                read -p "Local Port: " local_port
                read -p "Domain (or leave blank for IP-based proxy): " domain
                read -p "Enable SSL? (yes/no): " ssl
                add_proxy "$public_port" "$local_port" "$domain" "$ssl"
                ;;
            "Remove Proxy")
                read -p "Public Port to remove: " public_port
                remove_proxy "$public_port"
                ;;
            "List Proxies") list_proxies ;;
            "Renew SSL") renew_ssl ;;
            "Exit") exit 0 ;;
        esac
    done
}

case "$1" in
    "interactive") interactive_mode ;;
    "add") add_proxy "$2" "$3" "$4" "$5" ;;
    "remove") remove_proxy "$2" ;;
    "list") list_proxies ;;
    "renew-ssl") renew_ssl ;;
    "cleanup") cleanup ;;
    *) echo "Invalid command. Use 'interactive' for guided mode." ;;
esac
