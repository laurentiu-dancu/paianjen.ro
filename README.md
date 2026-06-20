# paianjen.ro

*Mic motor de căutare imobiliară*

Real estate search engine focused on Cluj County, Romania. Built with **Phoenix LiveView** + **HTMX**.

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Elixir 1.17 |
| Framework | Phoenix 1.7 + LiveView 1.0 |
| Frontend | HTMX + Tailwind CSS + LiveView |
| Database | PostgreSQL 16 |
| Server | Bandit (Elixir-native) |
| Dev Environment | Docker Compose |

## Quick Start

### Prerequisites

- Docker & Docker Compose

### Setup

```bash
# Build and start everything
make build
make up

# First-time setup (deps, DB, migrations, seeds)
make setup

# Or step by step:
make db-create
make db-migrate
make db-seed
```

Visit **http://localhost:4000**

### Development

```bash
# Interactive Phoenix server with live reload
make server

# Run tests
make test

# View logs
make logs

# Open a shell in the container
make shell
```

## Architecture

```
paianjen.ro/
├── assets/            # JS, CSS, Tailwind config
│   ├── js/app.js      # HTMX + LiveView bootstrap
│   └── css/app.css    # Tailwind + custom styles
├── config/            # Phoenix config (dev/test/prod)
├── lib/
│   ├── paianjen/      # Domain context (Listings)
│   └── paianjen_web/  # Web layer
│       ├── live/      # LiveViews (Page, Listing)
│       ├── controllers/  # HTMX API endpoints
│       └── components/   # Shared UI components
├── priv/
│   └── repo/          # Migrations + seeds
├── rel/               # Release config
├── docker-compose.yml
├── Dockerfile
└── Makefile
```

## HTMX + LiveView Integration

This project uses **both** HTMX and LiveView together:

- **LiveView** handles real-time interactivity (filter forms, navigation, flash messages)
- **HTMX** handles partial page updates via the `/api/*` endpoints for lightweight HTML fragment swaps
- The `htmx_request_type` pipeline plug detects HTMX requests for conditional rendering

## Data Pipeline

Data flows from **little-spider** → export bundle → SCP → **paianjen** ingest script.
See `docs/paianjen-vision.md` for the full architecture.

## License

Private — paianjen.ro
