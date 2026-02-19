---
name: custom-site-setup
user-invocable: true
description: Sets up a local development site with nginx, SSL via mkcert, and /etc/hosts entry. Use when user asks to set up a local site, configure nginx for a project, or create a .test domain.
allowed-tools: Bash(pwd, ls, cat, grep, ping), Read, Write, Glob, AskUserQuestion
---

# Local Site Setup

This skill sets up a local development site with nginx, SSL certificates, and DNS resolution.

## Prerequisites

The following must be installed on the system:
- nginx
- mkcert (with local CA installed)

## Process

### Step 1: Gather Information

Use AskUserQuestion to ask:

1. **Domain name**: What domain should be used? (e.g., `myproject.test`)
   - Default suggestion: derive from current directory name + `.test`

2. **Document root**: What is the public directory?
   - Options: `public`, `public_html`, or current directory
   - Default: `public` (standard for Laravel/PHP projects)

### Step 2: Detect Current Project

```bash
pwd
```

Use this as the base path for the site root.

### Step 3: Check for Existing Setup

Check if the domain already exists:
- Check `/etc/hosts` for the domain (use `grep`)
- Check if nginx config exists (ask user to run: `ls /etc/nginx/sites-enabled/ | grep <domain>`)

If already configured, inform the user and ask if they want to reconfigure.

### Step 4: Create Nginx Config

Create the nginx config file in the current project directory as `<domain>.conf`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name <DOMAIN>;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name <DOMAIN>;
    root <PROJECT_PATH>/<PUBLIC_DIR>;

    ssl_certificate <HOME>/.local/share/mkcert/<DOMAIN>.pem;
    ssl_certificate_key <HOME>/.local/share/mkcert/<DOMAIN>-key.pem;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass <PHP_FPM_ADDRESS>;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

Replace placeholders:
- `<DOMAIN>` - the chosen domain
- `<PROJECT_PATH>` - absolute path to project (from pwd)
- `<PUBLIC_DIR>` - the public directory (e.g., `public`)
- `<HOME>` - user's home directory
- `<PHP_FPM_ADDRESS>` - Always use `127.0.0.1:9000`

### Step 5: Provide Commands

After creating the config file, provide all commands at once for the user to run:

```bash
mkcert -cert-file ~/.local/share/mkcert/<DOMAIN>.pem -key-file ~/.local/share/mkcert/<DOMAIN>-key.pem <DOMAIN>
sudo mv <PROJECT_PATH>/<DOMAIN>.conf /etc/nginx/sites-enabled/
echo "127.0.0.1 <DOMAIN>" | sudo tee -a /etc/hosts
sudo nginx -t && sudo systemctl reload nginx
```

### Step 6: Verify Setup

After user runs the commands, suggest they test by visiting `https://<DOMAIN>` in their browser.

## Edge Cases

### mkcert Directory Missing
If `~/.local/share/mkcert/` doesn't exist:
```bash
mkdir -p ~/.local/share/mkcert
```

### Domain Already in /etc/hosts
Skip the hosts entry command if domain already exists.

### Nginx Config Already Exists
Warn the user that running the mv command will overwrite the existing config.

### Non-PHP Projects
For static sites, provide an alternative config without the PHP location block. Ask the user if this is a PHP project.

## Don'ts

1. **DON'T** attempt to run sudo commands directly - always provide them for the user to run
2. **DON'T** modify /etc/hosts or nginx configs without user explicitly running the commands
3. **DON'T** ask about PHP-FPM address - always use `127.0.0.1:9000`
4. **DON'T** create the config in /etc/nginx directly - always create in project directory first

## Success Criteria

- Nginx config file created in project directory
- User provided with all necessary commands
- Commands executed successfully by user
- Site accessible at https://<DOMAIN>
