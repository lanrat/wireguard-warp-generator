#!/bin/bash
#
# warp-register.sh - Register with Cloudflare WARP and generate WireGuard config
#
# Usage: ./warp-register.sh > warp.conf
#        ./warp-register.sh -v > warp.conf  # verbose mode
#        ./warp-register.sh --qr            # display QR code in terminal
#
# Options:
#   -v, --verbose     Print verbose output including API response to stderr
#   -q, --qr          Display QR code in terminal (requires qrencode)
#   -i, --info        Display account info to stderr
#
# Environment variables (with defaults):
#   WARP_DNS          - DNS servers (default: "1.1.1.1, 1.0.0.1")
#   WARP_MTU          - Interface MTU (default: 1280)
#   WARP_ALLOWED_IPS  - Allowed IPs (default: "0.0.0.0/0, ::/0")
#   WARP_LISTEN_PORT  - Listen port (default: 0, omitted from config)
#   WARP_PERSISTENT_KEEPALIVE - Persistent keepalive in seconds (default: 0, omitted from config)
#   WARP_DEVICE_TYPE  - Device type for registration (default: "Linux")
#   WARP_LOCALE       - Locale for registration (default: "en_US")
#   WARP_TOS_DATE     - Terms of service date (default: current date)

set -euo pipefail

# Flags
VERBOSE=false
SHOW_QR=false
SHOW_INFO=false

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--qr)
                SHOW_QR=true
                shift
                ;;
            -i|--info)
                SHOW_INFO=true
                shift
                ;;
            -h|--help)
                head -n 22 "$0" | tail -n +2 | sed 's/^# \?//'
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Use -h or --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# Log verbose messages to stderr
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

# Default configuration (can be overridden via environment variables)
: "${WARP_DNS:=1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001}"
: "${WARP_MTU:=1280}"
: "${WARP_ALLOWED_IPS:=0.0.0.0/0, ::/0}"
: "${WARP_LISTEN_PORT:=0}"
: "${WARP_PERSISTENT_KEEPALIVE:=0}"
: "${WARP_DEVICE_TYPE:=Linux}"
: "${WARP_LOCALE:=en_US}"
: "${WARP_TOS_DATE:=$(date -u +"%Y-%m-%dT%H:%M:%S.000+00:00")}"

# API endpoint
WARP_API_URL="https://api.cloudflareclient.com/v0a737/reg"

# Check for required dependencies
check_dependencies() {
    local missing=()

    for cmd in wg curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing[*]}" >&2
        echo "Please install them and try again." >&2
        exit 1
    fi

    # Check for qrencode if --qr flag is set
    if [[ "$SHOW_QR" == true ]] && ! command -v qrencode &>/dev/null; then
        echo "Error: qrencode is required for --qr flag" >&2
        echo "Install it with: apt install qrencode / brew install qrencode" >&2
        exit 1
    fi
}

# Generate WireGuard keypair
generate_keypair() {
    PRIVATE_KEY=$(wg genkey)
    PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

    if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
        echo "Error: Failed to generate WireGuard keypair" >&2
        exit 1
    fi

    log_verbose "Generated public key: $PUBLIC_KEY"
}

# Register with Cloudflare WARP API
register_with_warp() {
    local payload
    payload=$(cat <<EOF
{
    "key": "$PUBLIC_KEY",
    "install_id": "",
    "warp_enabled": true,
    "tos": "$WARP_TOS_DATE",
    "type": "$WARP_DEVICE_TYPE",
    "locale": "$WARP_LOCALE"
}
EOF
)

    log_verbose "Request payload:"
    if [[ "$VERBOSE" == true ]]; then
        echo "$payload" | jq . >&2
    fi

    WARP_RESPONSE=$(curl -sS -f -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$WARP_API_URL" 2>&1) || {
        echo "Error: Failed to register with Cloudflare WARP API" >&2
        echo "Response: $WARP_RESPONSE" >&2
        exit 1
    }

    log_verbose "API Response:"
    if [[ "$VERBOSE" == true ]]; then
        echo "$WARP_RESPONSE" | jq . >&2
    fi

    # Validate response contains expected fields
    if ! echo "$WARP_RESPONSE" | jq -e '.config.peers[0].public_key' &>/dev/null; then
        echo "Error: Invalid response from WARP API - missing peer public key" >&2
        echo "Response: $WARP_RESPONSE" >&2
        exit 1
    fi

    if ! echo "$WARP_RESPONSE" | jq -e '.config.interface.addresses' &>/dev/null; then
        echo "Error: Invalid response from WARP API - missing interface addresses" >&2
        echo "Response: $WARP_RESPONSE" >&2
        exit 1
    fi
}

# Extract configuration from WARP response
parse_warp_response() {
    # Get peer public key
    PEER_PUBLIC_KEY=$(echo "$WARP_RESPONSE" | jq -r '.config.peers[0].public_key')
    log_verbose "Peer public key: $PEER_PUBLIC_KEY"

    # Get IPv4 address
    INTERFACE_IPV4=$(echo "$WARP_RESPONSE" | jq -r '.config.interface.addresses.v4')
    log_verbose "Interface IPv4: $INTERFACE_IPV4"

    # Get IPv6 address
    INTERFACE_IPV6=$(echo "$WARP_RESPONSE" | jq -r '.config.interface.addresses.v6')
    log_verbose "Interface IPv6: $INTERFACE_IPV6"

    # Log the full endpoint object for debugging
    log_verbose "Endpoint object from response:"
    if [[ "$VERBOSE" == true ]]; then
        echo "$WARP_RESPONSE" | jq '.config.peers[0].endpoint' >&2
    fi

    # Get endpoint from response
    # The API returns host as "hostname:port" (e.g., "engage.cloudflareclient.com:2408")
    PEER_ENDPOINT=$(echo "$WARP_RESPONSE" | jq -r '.config.peers[0].endpoint.host // empty')
    log_verbose "Parsed endpoint: $PEER_ENDPOINT"

    if [[ -z "$PEER_ENDPOINT" ]]; then
        echo "Error: Could not extract endpoint from response" >&2
        exit 1
    fi

    if [[ -z "$PEER_PUBLIC_KEY" || "$PEER_PUBLIC_KEY" == "null" ]]; then
        echo "Error: Could not extract peer public key from response" >&2
        exit 1
    fi

    if [[ -z "$INTERFACE_IPV4" || "$INTERFACE_IPV4" == "null" ]]; then
        echo "Error: Could not extract IPv4 address from response" >&2
        exit 1
    fi
}

# Display account info
display_account_info() {
    echo "" >&2
    echo "=== Account Info ===" >&2
    echo "Account ID:   $(echo "$WARP_RESPONSE" | jq -r '.account.id // "-"')" >&2
    echo "Device ID:    $(echo "$WARP_RESPONSE" | jq -r '.id // "-"')" >&2
    echo "Account Type: $(echo "$WARP_RESPONSE" | jq -r '(if .account.warp_plus then "WARP+ " else "" end) + (.account.account_type // "free")')" >&2
    echo "License:      $(echo "$WARP_RESPONSE" | jq -r '.account.license // "-"')" >&2
    echo "Created:      $(echo "$WARP_RESPONSE" | jq -r '.created // "-"')" >&2
    echo "Expires:      $(echo "$WARP_RESPONSE" | jq -r '.account.ttl // "-"')" >&2
    echo "" >&2
}

# Generate WireGuard configuration
generate_wireguard_config() {
    local address="$INTERFACE_IPV4/32"

    # Add IPv6 if available
    if [[ -n "$INTERFACE_IPV6" && "$INTERFACE_IPV6" != "null" ]]; then
        address="$address, $INTERFACE_IPV6/128"
    fi

    # Build listen port line only if non-zero
    local listen_port_line=""
    if [[ "$WARP_LISTEN_PORT" != "0" ]]; then
        listen_port_line="ListenPort = $WARP_LISTEN_PORT"
    fi

    # Build persistent keepalive line only if non-zero
    local persistent_keepalive_line=""
    if [[ "$WARP_PERSISTENT_KEEPALIVE" != "0" ]]; then
        persistent_keepalive_line="PersistentKeepalive = $WARP_PERSISTENT_KEEPALIVE"
    fi

    cat <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $address
DNS = $WARP_DNS
MTU = $WARP_MTU
${listen_port_line:+$listen_port_line
}
[Peer]
PublicKey = $PEER_PUBLIC_KEY
AllowedIPs = $WARP_ALLOWED_IPS
Endpoint = $PEER_ENDPOINT
${persistent_keepalive_line:+$persistent_keepalive_line}
EOF
}

# Display QR code in terminal
display_qr_code() {
    local config="$1"
    echo "" >&2
    echo "=== QR Code (scan with WireGuard mobile app) ===" >&2
    echo "$config" | qrencode -t ANSIUTF8 >&2
    echo "" >&2
}

# Main execution
main() {
    parse_args "$@"

    echo "Checking dependencies..." >&2
    check_dependencies

    echo "Generating WireGuard keypair..." >&2
    generate_keypair

    echo "Registering with Cloudflare WARP..." >&2
    register_with_warp

    echo "Parsing response..." >&2
    parse_warp_response

    # Display account info if requested
    if [[ "$SHOW_INFO" == true ]]; then
        display_account_info
    fi

    echo "Generating WireGuard configuration..." >&2

    # Generate config to variable so we can use it for both output and QR
    local config
    config=$(generate_wireguard_config)

    # Display QR code if requested
    if [[ "$SHOW_QR" == true ]]; then
        display_qr_code "$config"
    fi

    echo "" >&2

    # Output config to stdout
    echo "$config"
}

main "$@"
