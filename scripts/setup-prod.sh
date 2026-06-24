#!/bin/bash
set -e

# ============================================================
# paianjen.ro — Production Setup Script
# Run on a fresh Ubuntu 22.04/24.04 VPS with sudo access
# ============================================================

if [ "$EUID" -ne 0 ]; then
  echo "Please run with sudo: sudo bash scripts/setup-prod.sh"
  exit 1
fi

echo "============================================"
echo "  paianjen.ro — Production Setup"
echo "============================================"
echo ""

# ---- 1. System dependencies ----
echo "[1/8] Installing system packages..."
apt update -y
apt upgrade -y
apt install -y \
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

echo "System packages installed."

# ---- 2. asdf ----
echo ""
echo "[2/8] Installing asdf (version manager)..."
if [ ! -d "/root/.asdf" ]; then
  git clone https://github.com/asdf-vm/asdf.git /root/.asdf --branch v0.14.0
  echo '. "/root/.asdf/asdf.sh"' >> /root/.bashrc
  echo '. "/root/.asdf/completions/asdf.bash"' >> /root/.bashrc
  source /root/.asdf/asdf.sh
  echo "asdf installed."
else
  echo "asdf already installed, skipping."
fi

# ---- 3. Erlang ----
echo ""
echo "[3/8] Installing Erlang 27.0.1..."
if ! asdf list erlang 2>/dev/null | grep -q "27.0.1"; then
  asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git 2>/dev/null || true
  asdf install erlang 27.0.1
  asdf global erlang 27.0.1
  echo "Erlang installed."
else
  asdf global erlang 27.0.1
  echo "Erlang 27.0.1 already installed, skipping."
fi

# ---- 4. Elixir ----
echo ""
echo "[4/8] Installing Elixir 1.17.2-otp-27..."
if ! asdf list elixir 2>/dev/null | grep -q "1.17.2-otp-27"; then
  asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git 2>/dev/null || true
  asdf install elixir 1.17.2-otp-27
  asdf global elixir 1.17.2-otp-27
  echo "Elixir installed."
else
  asdf global elixir 1.17.2-otp-27
  echo "Elixir 1.17.2-otp-27 already installed, skipping."
fi

# ---- 5. Node.js ----
echo ""
echo "[5/8] Installing Node.js 20..."
if ! asdf list nodejs 2>/dev/null | grep -q "20"; then
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git 2>/dev/null || true
  asdf install nodejs 20.11.0
  asdf global nodejs 20.11.0
  echo "Node.js installed."
else
  asdf global nodejs 20.11.0
  echo "Node.js already installed, skipping."
fi

# Reload asdf
source /root/.asdf/asdf.sh

echo ""
echo "=== Toolchain installed ==="
echo "Erlang: $(erl -version 2>&1)"
echo "Elixir: $(elixir -v | head -1)"
echo "Node:   $(node -v)"

# ---- 6. PostgreSQL ----
echo ""
echo "[6/8] Setting up PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

DB_USER="paianjen"
DB_PASS="paianjen_prod_$(openssl rand -hex 8)"
DB_NAME="paianjen_prod"

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' CREATEDB;"
  echo "Database user '$DB_USER' created."
else
  echo "Database user '$DB_USER' already exists, skipping creation."
fi

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
  echo "Database '$DB_NAME' created."
else
  echo "Database '$DB_NAME' already exists, skipping creation."
fi

# ---- 7. Application build ----
echo ""
echo "[7/8] Building the application..."
APP_DIR="/opt/paianjen"

if [ ! -d "$APP_DIR" ]; then
  echo "Cloning repository..."
  git clone https://github.com/YOUR_USER/paianjen.ro.git "$APP_DIR"
fi

cd "$APP_DIR"

echo "Installing Hex and Rebar..."
mix local.hex --force
mix local.rebar --force

echo "Installing dependencies..."
MIX_ENV=prod mix deps.get

echo "Building assets..."
cd assets && npm install && npm run deploy && cd ..

echo "Compiling and building release..."
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile
MIX_ENV=prod mix release

echo "Release built at: $APP_DIR/_build/prod/rel/paianjen"

# ---- 8. Configuration ----
echo ""
echo "[8/8] Creating configuration files..."

SECRET_KEY=$(mix phx.gen.secret 64)

# Create .env file
cat > "$APP_DIR/.env" << ENVEOF
DATABASE_URL=ecto://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
SECRET_KEY_BASE=${SECRET_KEY}
PHX_HOST=localhost
PORT=4000
POOL_SIZE=10
ERL_AFLAGS=-proto_dist inet6_tcp
ENVEOF

chmod 600 "$APP_DIR/.env"

# Create prod.secret.exs
cat > "$APP_DIR/config/prod.secret.exs" << 'SECRETEOF'
import Config

config :paianjen, PaianjenWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  url: [host: System.get_env("PHX_HOST") || "localhost", port: 443],
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")]

config :paianjen, Paianjen.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: false
SECRETEOF

# Create systemd service
cat > /etc/systemd/system/paianjen.service << 'SERVICEEOF'
[Unit]
Description=Paianjen Web App
After=network.target postgresql.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/paianjen
Environment=LANG=en_US.UTF-8
EnvironmentFile=/opt/paianjen/.env
ExecStart=/opt/paianjen/bin/paianjen start
ExecStop=/opt/paianjen/bin/paianjen stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable paianjen

# Create deploy script
cat > "$APP_DIR/bin/deploy.sh" << 'DEPLOYEOF'
#!/bin/bash
set -e
cd /opt/paianjen
git pull origin main
MIX_ENV=prod mix deps.get
cd assets && npm install && npm run deploy && cd ..
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
source .env
bin/paianjen eval 'Paianjen.Release.migrate()'
sudo systemctl restart paianjen
DEPLOYEOF
chmod +x "$APP_DIR/bin/deploy.sh"

# Create Nginx config
cat > /etc/nginx/sites-available/paianjen << 'NGINXEOF'
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
NGINXEOF

ln -sf /etc/nginx/sites-available/paianjen /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# ---- Summary ----
echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Database:"
echo "  User: $DB_USER"
echo "  Pass: $DB_PASS"
echo "  Name: $DB_NAME"
echo ""
echo "Application:"
echo "  Dir:    $APP_DIR"
echo "  Release: $APP_DIR/_build/prod/rel/paianjen"
echo "  Deploy: $APP_DIR/bin/deploy.sh"
echo ""
echo "Next steps:"
echo "  1. Edit $APP_DIR/.env and set PHX_HOST to your domain"
echo "  2. Edit $APP_DIR/config/prod.secret.exs with correct host"
echo "  3. Set up DNS to point to this server"
echo "  4. Run: sudo systemctl start paianjen"
echo "  5. Run: sudo certbot --nginx -d yourdomain.com"
echo ""
echo "To deploy updates later:"
echo "  ssh root@server 'bash /opt/paianjen/bin/deploy.sh'"
echo ""
