alias Paianjen.Repo
alias Paianjen.Listings.Listing

Repo.insert!(%Listing{
  id: "00000000-0000-0000-0000-000000000001",
  title: "Apartament 2 camere, mobilat, Zorilor",
  description: "Apartament frumos, mobilat, în zona Zorilor. Ideal pentru cuplu.",
  price: 85_000,
  currency: "EUR",
  rooms: 2,
  surface_area: 52,
  floor: 3,
  seller_type: "private",
  district: "Zorilor",
  first_seen_at: ~U[2026-06-18 10:00:00Z],
  last_scraped_at: DateTime.utc_now(),
  is_delisted: false
})

Repo.insert!(%Listing{
  id: "00000000-0000-0000-0000-000000000002",
  title: "Garsoneră renovată, Mărăști",
  description: "Garsoneră complet renovată, centrală termică proprie.",
  price: 55_000,
  currency: "EUR",
  rooms: 1,
  surface_area: 32,
  floor: 1,
  seller_type: "private",
  district: "Mărăști",
  first_seen_at: ~U[2026-06-19 14:30:00Z],
  last_scraped_at: DateTime.utc_now(),
  is_active: true
})

Repo.insert!(%Listing{
  title: "Apartament 3 camere, Gruia",
  description: "Apartament spațios în zona Gruia, vedere panoramică.",
  price: 120_000,
  currency: "EUR",
  rooms: 3,
  surface: 75,
  floor: 5,
  seller_type: "agency",
  district: "Gruia",
  first_discovered: ~U[2026-06-15 09:00:00Z],
  last_seen: DateTime.utc_now(),
  is_active: true
})

IO.puts("✅ Seeded 3 listings")
