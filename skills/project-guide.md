# paianjen.ro — Project Guide

## Overview

Romanian real estate listing aggregator. Scrapes listings from sites like Imobiliare.ro, groups similar apartments, and presents them as a searchable catalog.

**Stack:** Phoenix 1.8 + LiveView + PostgreSQL 16 + Tailwind CSS

## Development Environment

### Docker Compose

```bash
# Start everything
docker compose up

# Run migrations
docker compose exec app mix ecto.migrate

# Compile
docker compose exec app mix compile

# Open IEx shell
docker compose exec app iex -S mix

# Run tests
docker compose exec app mix test
```

### Database

```bash
# Connect to DB
docker compose exec db psql -U paianjen -d paianjen_dev

# Useful queries
SELECT count(*) FROM listing_groups;
SELECT count(*) FROM listings;
SELECT count(*) FROM listing_groups WHERE has_active_listings = false;
\d listing_groups   # show table schema
\d listings         # show table schema
```

### Import Data

```bash
# Full import from JSONL export
docker compose exec app mix run priv/repo/import_from_export.exs data/paianjen_export_full.jsonl
```

The import script:
- Upserts groups + listings + similar groups
- Computes min/max price, surface, days on market
- Sets `has_active_listings` flag (false if all listings delisted)
- Recomputes `earliest_first_seen` from actual DB data

## Architecture

### Key Tables

| Table | Purpose |
|-------|---------|
| `listing_groups` | Canonical apartment groups (deduplicated) |
| `listings` | Individual listings from various sources |
| `similar_groups` | Pre-computed similar group pairs with scores |

### Key Fields on `listing_groups`

- `group_city`, `group_district`, `group_zone` — location (from canonical listing)
- `group_thumbnail` — image URL
- `min_price`, `max_price`, `min_surface`, `max_surface` — from active listings
- `earliest_first_seen` — for "days on market" calculation
- `has_active_listings` — boolean, indexed. **Groups with only delisted listings are filtered out everywhere.**
- `has_top_floor`, `has_private_seller` — flags computed at import time

### Key Fields on `listings`

- `group_id` — FK to listing_groups
- `is_canonical` — the "primary" listing for a group
- `is_delisted` — whether the listing is no longer active
- `is_private_seller` — private vs agency
- `agency_commission` — 0 means "comision 0"
- `price`, `surface_area`, `rooms`, `floor`, `total_floors`
- `parking_price`, `balcony_surface`
- `search_vector` — tsvector for full-text search (Romanian)
- `images` — array of URLs
- `thumbnail` — primary image
- `url` — original listing URL

### Core Modules

| Module | Role |
|--------|------|
| `Paianjen.Listings` | Context: queries, filters, import logic |
| `Paianjen.Listings.GroupPresenter` | Transforms DB schema → flat UI format |
| `Paianjen.Listings.ListingGroup` | Ecto schema for listing_groups |
| `Paianjen.Listings.Listing` | Ecto schema for listings |
| `Paianjen.Listings.SimilarGroup` | Ecto schema for similar_groups |
| `PaianjenWeb.ListingLive.Index` | Main listing page (groups grid) |
| `PaianjenWeb.ListingLive.Show` | Detail page (individual listings + similar) |

### GroupPresenter Struct

The flat format used by LiveView templates. Fields: `id, city, district, zone, min_price, max_price, min_surface, max_surface, rooms, floor, total_floors, year_built, image_url, parking_price, days_on_market, active_listings, total_listings, listings, health_pct, has_active_listings`.

**Important:** When adding a new field to the DB schema, you must also:
1. Add it to the `defstruct` in GroupPresenter
2. Populate it in `from_group/2`
3. Update the `ListingGroup.changeset/2` if it's a user-settable field

## Filter System

All filters live in the `Index` LiveView's assigns. The filter form uses `phx-submit="apply_filters"` (not `phx-change` — that was too aggressive with auto-submit on every keystroke).

### Filter Pipeline (server-side)

`list_groups_paginated/1` chains Ecto queries:
1. `filter_by_active` — `has_active_listings == true` (always on by default)
2. `filter_by_city` — exact match on `group_city`
3. `filter_by_district` — exact match on `group_district`
4. `filter_by_min_price` — `max_price >= ^min_price` (group has listing ≥ min)
5. `filter_by_max_price` — `min_price <= ^max_price` (group has listing ≤ max)
6. `filter_by_min_surface` — `max_surface >= ^min_sqm`
7. `filter_by_max_surface` — `min_surface <= ^max_sqm`
8. `filter_by_parking` — subquery: group has listing with `parking_price > 0`
9. `filter_by_commission` — subquery: group has listing with `agency_commission == 0 AND is_private_seller == false`
10. `filter_by_search` — full-text search via `search_vector @@ plainto_tsquery('romanian', ...)`

### Filter Helpers (private)

All filter helpers follow the same pattern:
```elixir
defp filter_by_city(query, opts) do
  case Keyword.get(opts, :city) do
    nil -> query
    "" -> query
    city -> where(query, [g], g.group_city == ^city)
  end
end
```

### Adding a New Filter

1. Add filter to `default_filters/0` in Index
2. Add `handle_event` for toggle filters, or form binding for text/number filters
3. Add `filter_by_<name>/2` private function in `Listings.ex`
4. Add filter to `list_groups/1` and `list_groups_paginated/1` pipelines
5. Add to `active_filter_count/1` if it should count as an active filter
6. Add UI element in `filter_panel/1` template

## Pagination

Page-based with `OFFSET`. Page size is 8 (set in `@page_size` on Index).

- `load_more` event appends next page to existing groups
- `InfiniteScroll` JS hook observes a sentinel div at the bottom
- `ScrollToGroup` JS hook handles return-from-detail scroll position

## Return Context (sessionStorage)

When navigating from index → detail, the current filters + page + clicked group ID are stored in `sessionStorage` under `"return_context"`. On returning to index:

1. `ScrollToGroup` hook reads sessionStorage
2. Sends `restore_context` event to server with filters + page
3. Server loads correct page with those filters
4. Client polls for the group card and scrolls to it with a brief highlight

**Detail links use same-tab navigation** (no `target="_blank"`) so sessionStorage works.

## JS Hooks

Defined in `assets/js/app.js`, must be defined **before** `LiveSocket` constructor:

| Hook | Purpose |
|------|---------|
| `InfiniteScroll` | IntersectionObserver on sentinel div → pushes `load_more` |
| `ImageSlider` | Image carousel on detail page (dots, prev/next) |
| `ScrollToGroup` | Reads sessionStorage, restores context, scrolls to group card |

## Common Tasks

### Adding a New DB Column

1. Create migration: `mix ecto.gen.migration add_field_to_table`
2. Run migration: `docker compose exec app mix ecto.migrate`
3. Update the schema (`lib/paianjen/listings/listing_group.ex`)
4. Update `GroupPresenter` struct + `from_group/2`
5. Update import script if the field comes from scraped data
6. Update queries/filters if the field should be filterable

### Adding a New Page

1. Create LiveView in `lib/paianjen_web/live/`
2. Add route in `router.ex`
2. Add `live_session` if needed
4. Create the template in the `render/1` callback

### Debugging DB Queries

```bash
# In IEx
import Ecto.Query
alias Paianjen.Repo
alias Paianjen.Listings.ListingGroup

# Check query plan
Ecto.Adapters.SQL.explain(Repo, :all, from(g in ListingGroup, where: g.group_city == "Cluj-Napoca"))
```

### Checking Import Data Format

```bash
# Peek at export file
head -1 data/paianjen_export_full.jsonl | python3 -m json.tool
```

## Project Structure Conventions

- **Migrations:** `priv/repo/migrations/YYYYMMDDHHMMSS_name.exs`
- **Schemas:** `lib/paianjen/listings/*.ex`
- **LiveViews:** `lib/paianjen_web/live/_*_live/*.ex`
- **Components:** `lib/paianjen_web/components/core_components.ex`
- **JS Hooks:** `assets/js/app.js` (must be before LiveSocket)
- **CSS:** `assets/css/app.css` (Tailwind)

## Gotchas

- **`has_active_listings` must be re-run after import** — it's computed at import time, not queried live
- **Filter toggles (parking, commission) bypass the form** — they use `phx-click="toggle_parking"` directly, not form submission
- **Full-text search uses Romanian dictionary** — `plainto_tsquery('romanian', ...)`
- **GroupPresenter is the bridge** — never access raw DB schemas in templates, always go through GroupPresenter
- **sessionStorage key is `"return_context"`** — don't change this without updating both JS and Elixir code
