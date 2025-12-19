# WARP Registration Script

Shell script to register with Cloudflare WARP and generate a WireGuard configuration file.

## Dependencies

- `wg` (WireGuard tools)
- `curl`
- `jq`
- `qrencode` (optional, for `--qr` flag)

## Usage

```bash
# Basic usage
./warp-register.sh > warp.conf

# With QR code display
./warp-register.sh --qr > warp.conf

# With account info
./warp-register.sh --info > warp.conf

# Verbose mode (shows API response)
./warp-register.sh -v > warp.conf

# Combined flags
./warp-register.sh --qr --info > warp.conf
```

## Options

| Flag | Description |
|------|-------------|
| `-v, --verbose` | Print verbose output including API response |
| `-q, --qr` | Display QR code in terminal (requires `qrencode`) |
| `-i, --info` | Display account info (ID, license, expiry) |
| `-h, --help` | Show help message |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WARP_DNS` | `1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001` | DNS servers |
| `WARP_MTU` | `1280` | Interface MTU |
| `WARP_ALLOWED_IPS` | `0.0.0.0/0, ::/0` | Allowed IPs (full tunnel by default) |
| `WARP_LISTEN_PORT` | `0` | Listen port (0 = random port) |
| `WARP_PERSISTENT_KEEPALIVE` | `0` | Keepalive interval in seconds (0 = disabled) |
| `WARP_DEVICE_TYPE` | `Linux` | Device type for registration |
| `WARP_LOCALE` | `en_US` | Locale |
| `WARP_TOS_DATE` | Current date | Terms of service agreement date |

## Examples

```bash
# Custom DNS servers
WARP_DNS="9.9.9.9, 1.1.1.1" ./warp-register.sh > warp.conf

# Split tunnel (only route specific IPs)
WARP_ALLOWED_IPS="1.1.1.1/32, 1.0.0.1/32" ./warp-register.sh > warp.conf

# With persistent keepalive (useful for NAT)
WARP_PERSISTENT_KEEPALIVE=25 ./warp-register.sh > warp.conf
```

## Connect

```bash
# Start the tunnel
wg-quick up ./warp.conf

# Stop the tunnel
wg-quick down ./warp.conf
```
