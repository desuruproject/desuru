# Desuru

**Making deployment simple** 🚀

One-command deployment for your JavaScript applications.

## Quick Start

**Step 1:** SSH into your Ubuntu server and navigate to your project directory:
```bash
cd /path/to/your/project
```

**Step 2:** Run the deployment command from your project directory:
```bash
curl -sSL https://raw.githubusercontent.com/desuruproject/desuru/refs/heads/main/desuru.sh | sudo bash -s -- \
  --app myapp \
  --domain example.com \
  --ssl \
  --email admin@example.com
```

**Step 3:** Wait for deployment to complete. Your app will be live at your domain!

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

## Managing Your App with PM2

After deployment, use these commands to manage your application:

```bash
# Check app status
pm2 status

# View app logs
pm2 logs your-app-name

# Restart your app
pm2 restart your-app-name

# Stop your app
pm2 stop your-app-name

# Monitor resources
pm2 monit
```

## Testing Status

✅ **Tested on:** Ubuntu with React and Node.js applications  
🚧 **More testing:** Additional frameworks and platforms coming soon

## Important Commands

```bash
# Check deployment logs
tail -50 /tmp/deploy-*.log

# Check nginx status
sudo systemctl status nginx

# Check nginx configuration
sudo nginx -t

# View nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

## Need Help?

1. **Check deployment logs:** `tail -50 /tmp/deploy-*.log`
2. **Verify your app is running:** `pm2 status`
3. **Check if domain points to server:** `ping your-domain.com`
4. **Ensure you're in project directory** with `package.json`

---

*Making deployment simple for developers everywhere*
