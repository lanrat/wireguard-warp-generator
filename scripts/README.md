# WARP Registration Script

Shell script to register with Cloudflare WARP and generate a WireGuard configuration file.

## Dependencies

- `wg` (WireGuard tools)
- `curl`
- `jq`

## Usage

```bash
# Basic usage
./warp-register.sh > warp.conf

# Verbose mode (shows API response)
./warp-register.sh -v > warp.conf

# Custom DNS servers
WARP_DNS="9.9.9.9, 1.1.1.1" ./warp-register.sh > warp.conf

# Split tunnel (only route specific IPs)
WARP_ALLOWED_IPS="1.1.1.1/32, 1.0.0.1/32" ./warp-register.sh > warp.conf

# With persistent keepalive
WARP_PERSISTENT_KEEPALIVE=25 ./warp-register.sh > warp.conf
```

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

## Connect

```bash
# Start the tunnel
wg-quick up ./warp.conf

# Stop the tunnel
wg-quick down ./warp.conf
```
