# WARP WireGuard Config Generator

Generate WireGuard configurations for Cloudflare WARP.

## Web App

**[https://lanrat.github.io/wireguard-warp-generator/](https://lanrat.github.io/wireguard-warp-generator/)**

A browser-based tool that generates configs entirely client-side. Features QR code for mobile import and customizable options.

## Shell Script

Command-line tool for generating WARP configs. See [scripts/README.md](scripts/README.md) for usage.

```bash
# Basic usage
./scripts/warp-register.sh > warp.conf

# With QR code and account info
./scripts/warp-register.sh --qr --info > warp.conf
```

## How It Works

1. Generates a WireGuard keypair locally
2. Registers the public key with Cloudflare's WARP API
3. Outputs a complete WireGuard configuration

## License

MIT
