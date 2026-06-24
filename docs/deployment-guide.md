# paianjen.ro — Production Deployment Guide

Deploy paianjen.ro to a bare Linux VPS without Docker. This guide covers everything from a fresh Ubuntu server to a running production instance.

This is the configuration that is known to work on the production VPS (`spider-vm`).

---

## 1. VPS Requirements

- **OS**: Ubuntu 22.04 LTS or 24.04 LTS
- **RAM**: 1 GB minimum (512 MB works but tight)
- **Disk**: 20 GB minimum
- **SSH access**: root or sudo user

---

## 2. System Dependencies

SSH into your server and install the required system packages:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  build-essential \
  git \
  curl \
  wget \
  postgresql \
  postgresql-contrib \
  libssl-dev \
  libffi-dev \
  zlib1g-dev \
  nodejs \
  npm \
  nginx \
  certbot \
  python3-certbot-nginx \
  inotify-tools
```

### Verify versions

```bash
# Erlang/Elixir will be installed via asdf (see below)
node -v    # should be 18+
psql --version
```

---

## 3. Install asdf (Version Manager)

asdf manages Erlang and Elixir versions:

```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
```

### Install Erlang

```bash
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf install erlang 27.0.1
asdf global erlang 27.0.1
```

### Install Elixir

```bash
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf install elixir 1.17.2-otp-27
asdf global elixir 1.17.2-otp-27
```

### Install Node.js (for asset builds)

```bash
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs 20.11.0
asdf global nodejs 20.11.0
```

### Verify

```bash
elixir -v
erl -version
node -v
```

---

## 4. Set Up PostgreSQL

```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database user
sudo -u postgres psql -c "CREATE USER paianjen WITH PASSWORD 'your_secure_password' CREATEDB;"
sudo -u postgres psql -c "CREATE DATABASE paianjen_prod OWNER paianjen;"
```

---

## 5. Set Up the Application

### Clone the repo

```bash
git clone https://github.com/YOUR_USER/paianjen.ro.git /opt/paianjen
cd /opt/paianjen
```

### Install dependencies

```bash
mix local.hex --force
mix local.rebar --force
MIX_ENV=prod mix deps.get
```

### Create `.env` file

This file is loaded by the systemd service and the deploy scripts:

```bash
cat > /opt/paianjen/.env << 'EOF'
DATABASE_URL=ecto://paianjen:YOUR_DB_PASSWORD@127.0.0.1:5432/paianjen_prod
SECRET_KEY_BASE=GENERATE_A_64_BYTE_SECRET
PHX_HOST=paianjen.ro
PORT=4000
POOL_SIZE=10
EOF
```

Generate a real secret:

```bash
mix phx.gen.secret 64
```

Replace `GENERATE_A_64_BYTE_SECRET` and `YOUR_DB_PASSWORD` with real values.

### Create `config/prod.secret.exs`

```elixir
import Config

secret_key_base = System.get_env("SECRET_KEY_BASE")
phx_host = System.get_env("PHX_HOST") || "paianjen.ro"
port = String.to_integer(System.get_env("PORT") || "4000")

config :paianjen, PaianjenWeb.Endpoint,
  secret_key_base: secret_key_base,
  url: [host: phx_host, port: 443],
  http: [ip: {127, 0, 0, 1}, port: port]
```

### Build for production

```bash
# Install JS dependencies and build assets
cd assets && npm install && npm run deploy && cd ..

# Compile and build release
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
```

This creates `_build/prod/rel/paianjen/` — a self-contained release.

---

## 6. Create the Systemd Service

Create `/etc/systemd/system/paianjen.service`:

```ini
[Unit]
Description=Paianjen Web App
After=network.target postgresql.service

[Service]
Type=simple
User=azureuser
Group=azureuser
WorkingDirectory=/opt/paianjen
Environment=LANG=en_US.UTF-8
EnvironmentFile=/opt/paianjen/.env
ExecStart=/opt/paianjen/_build/prod/rel/paianjen/bin/paianjen start
ExecStop=/opt/paianjen/_build/prod/rel/paianjen/bin/paianjen stop
Restart=on-failure
RestartSec=5

[Install]
Wanted-by=multi-user.target
```

**Important**: Replace `User=azureuser` with your actual user. The release path must point to the actual release directory.

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable paianjen
sudo systemctl start paianjen
```

Check status:

```bash
sudo systemctl status paianjen
journalctl -u paianjen -f
```

---

## 7. Run Migrations

```bash
sudo -u azureuser bash -c "set -a && source /opt/paianjen/.env && /opt/paianjen/_build/prod/rel/paianjen/bin/paianjen eval 'Paianjen.Release.migrate()'"
```

---

## 8. Set Up Nginx as Reverse Proxy

Create `/etc/nginx/sites-available/paianjen`:

```nginx
server {
    listen 80;
    server_name paianjen.ro www.paianjen.ro;

    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120000;
        proxy_send_timeout 120000;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/paianjen /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## 9. SSL with Let's Encrypt

```bash
sudo certbot --nginx -d paianjen.ro -d www.paianjen.ro
```

Certbot will automatically update your Nginx config and set up auto-renewal.

---

## 10. Deployment Script (for little-spider to use)

Create `/opt/paianjen/bin/deploy.sh`:

```bash
#!/bin/bash
set -e

cd /opt/paianjen

# Pull latest code
git pull origin main

# Install dependencies (only if changed)
MIX_ENV=prod mix deps.get

# Build assets
cd assets && npm install && npm run deploy && cd ..

# Compile and release
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile
MIX_ENV=prod mix release

# Run migrations
source .env
bin/paianjen eval 'Paianjen.Release.migrate()'

# Restart the service
sudo systemctl restart paianjen
```

Make it executable:

```bash
chmod +x /opt/paianjen/bin/deploy.sh
```

little-spider can now deploy by running:

```bash
ssh azureuser@paianjen.ro "cd /opt/paianjen && bash bin/deploy.sh"
```

The deploy script will:
1. Pull latest code
2. Build assets and compile
3. Create a new release
4. Run database migrations
5. Import the uploaded export file (if present)
6. Restart the systemd service

---

## 11. Troubleshooting

### Check logs

```bash
journalctl -u paianjen -f
```

### Restart the app

```bash
sudo systemctl restart paianjen
```

### Rollback migrations

```bash
cd /opt/paianjen
source .env
# Rollback to specific version
bin/paianjen eval 'Paianjen.Release.rollback(Paianjen.Repo, VERSION)'
```

### Connect to production database

```bash
sudo -u postgres psql paianjen_prod
```

### Check if app is running

```bash
sudo systemctl status paianjen
curl http://localhost:4000
```

---

## 12. Architecture Overview

```
Internet → Nginx (:80/:443) → paianjen app (:4000) → PostgreSQL (:5432)
```

- **Nginx**: Handles SSL termination, serves static files, proxies WebSocket connections
- **paianjen app**: Phoenix/Erlang release running as systemd service
- **PostgreSQL**: Local database on the same machine

The release is self-contained — it bundles the Erlang runtime, all BEAM code, and the asset files. No need for Elixir/Erlang source on the target machine after building.

---

## 13. Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `ecto://user:pass@localhost:5432/db` |
| `SECRET_KEY_BASE` | 64-byte secret for sessions/signing | Generated by `mix phx.gen.secret` |
| `PHX_HOST` | Public hostname | `paianjen.ro` |
| `PORT` | Internal port the app listens on | `4000` |
| `POOL_SIZE` | Database connection pool size | `10` |
