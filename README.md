# Desuru - Universal JavaScript Framework Deployment

🚀 **One-command deployment for React, Next.js, Vue, Angular, Nuxt, Svelte, Gatsby, Node.js and more!**

## Quick Start

### Requirements
- Ubuntu/Debian server with root access
- Domain name pointing to your server (for SSL)

### Basic Usage

**Deploy from your project directory:**
```bash
sudo curl -sSL https://your-domain.com/desuru.sh | bash -s -- --app myapp --domain example.com
```

**With SSL:**
```bash
sudo curl -sSL https://your-domain.com/desuru.sh | bash -s -- \
  --app myapp \
  --domain example.com \
  --ssl \
  --email admin@example.com
```

### Safer Alternative (Recommended)
```bash
# Download and review the script first
curl -L https://your-domain.com/desuru.sh > desuru.sh
chmod +x desuru.sh

# Review the script content, then run:
sudo ./desuru.sh --app myapp --domain example.com --ssl --email admin@example.com
```

## Options

| Flag | Description | Example |
|------|-------------|---------|
| `--app` | Application name (required) | `--app myblog` |
| `--domain` | Domain or IP (required) | `--domain myblog.com` |
| `--port` | App port (default: 3000) | `--port 8080` |
| `--ssl` | Enable HTTPS with Let's Encrypt | `--ssl` |
| `--email` | Email for SSL (required with --ssl) | `--email admin@example.com` |
| `--instances` | PM2 instances (default: 1) | `--instances max` |
| `--memory` | Memory limit (default: 500M) | `--memory 1G` |

## Examples

**Frontend App (React/Vue/Angular):**
```bash
sudo ./desuru.sh --app frontend --domain myapp.com --ssl --email me@example.com
```

**Backend API:**
```bash
sudo ./desuru.sh --app api --domain api.myapp.com --port 3001 --ssl --email me@example.com
```

**High Performance:**
```bash
sudo ./desuru.sh --app webapp --domain myapp.com --instances max --memory 2G
```

## What It Does

1. ✅ Detects your JavaScript framework automatically
2. ✅ Installs Node.js, nginx, PM2 (if needed)
3. ✅ Builds your application
4. ✅ Configures nginx with security headers
5. ✅ Sets up SSL certificates (optional)
6. ✅ Starts your app with PM2 process management
7. ✅ Configures firewall rules

## Supported Frameworks

- **Frontend:** React, Vue.js, Angular, Svelte, Gatsby
- **Fullstack:** Next.js, Nuxt.js, SvelteKit
- **Backend:** Node.js, Express.js, any npm-based server

## Security Notes

⚠️ **This script requires root access and executes remote code. Only use on servers you control.**

- Always use HTTPS sources
- Review script content when possible
- Recommended for development/staging environments
- For production, download and audit the script first

## Troubleshooting

**Common Issues:**
- Ensure you're in your project root directory (where package.json is)
- Check domain DNS points to your server
- Verify ports 80/443 are open
- Review deployment logs: `tail -50 /tmp/deploy-*.log`

**Get Help:**
- Check nginx status: `systemctl status nginx`
- View app logs: `pm2 logs myapp`
- Test nginx config: `nginx -t`

## Support

For issues and questions, check the deployment logs first:
```bash
tail -50 /tmp/deploy-$(date +%Y%m%d)*.log
```

---

**Made with ❤️ for developers who want simple deployments**
