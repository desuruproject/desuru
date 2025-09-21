# Desuru

**Making deployment simple** 🚀

One-command deployment for your JavaScript applications.

## Quick Start

Run this command from your project directory:

```bash
curl -sSL https://raw.githubusercontent.com/desuruproject/desuru/refs/heads/main/desuru.sh | sudo bash -s -- \
  --app myapp \
  --domain example.com \
  --ssl \
  --email admin@example.com
```

That's it! Your app is now live.

## What You Need

- Ubuntu server with root access
- Domain name pointing to your server
- Your app's source code

## Options

| Flag | Description | Required |
|------|-------------|----------|
| `--app` | Your app name | ✅ |
| `--domain` | Your domain or IP | ✅ |
| `--ssl` | Enable HTTPS | No |
| `--email` | Email for SSL certificate | With --ssl |
| `--port` | App port (default: 3000) | No |

## What It Does

- Automatically detects your framework (React, Node.js, etc.)
- Installs dependencies (Node.js, nginx, PM2)
- Builds and deploys your app
- Sets up SSL certificates
- Configures security and firewall

## Testing Status

✅ **Tested on:** Ubuntu with React and Node.js applications  
🚧 **More testing:** Additional frameworks and platforms coming soon

## Need Help?

Check your deployment logs:
```bash
tail -50 /tmp/deploy-*.log
```

---

*Making deployment simple for developers everywhere*
