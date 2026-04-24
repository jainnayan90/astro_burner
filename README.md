# AstroBurner

A Phoenix application that calculates spacecraft fuel requirements for launch and landing maneuvers.

## Domain

**Fuel calculation** accounts for the fact that fuel itself has mass, so additional fuel is needed to carry the fuel. The calculation recurses until the fuel increment is zero or negative.

Formulas (result floored to integer):
- Launch: `mass × gravity × 0.042 − 33`
- Landing: `mass × gravity × 0.033 − 42`

**Planets** store a gravitational constant (`gravity`) used in the formulas. Three planets are seeded by default:

| Planet | Gravity (m/s²) |
|--------|----------------|
| Earth  | 9.807          |
| Moon   | 1.62           |
| Mars   | 3.711          |

## Key modules

- `AstroBurner.FuelCalculator` — recursive fuel calculation; takes mass (integer), planet UUID, and maneuver (`:launch` or `:landing`)
- `AstroBurner.Planets` — context for planet CRUD (`get_planet/1`, `list_planets/0`, `upsert_planet!/1`)
- `AstroBurner.Planets.Planet` — Ecto schema with UUID primary key, unique name, and decimal gravity

## Setup

```bash
mix setup        # deps + DB create + migrate + seed
mix phx.server   # start at http://localhost:4000
```

Or inside IEx:

```bash
iex -S mix phx.server
```

## Database

PostgreSQL with a single `planets` table (UUID primary key, unique name index, decimal gravity).

```bash
mix ecto.reset   # drop + recreate + migrate + seed
```

## Development

```bash
mix precommit    # compile (warnings-as-errors), format, unused deps check, tests
mix test         # run tests (auto-creates and migrates the test DB)
```

## Stack

- Elixir ~> 1.15 / Phoenix 1.8
- Phoenix LiveView 1.1
- Ecto + PostgreSQL (decimal gravity stored with full precision)
- Bandit HTTP server
- Tailwind CSS + esbuild
- ExMachina (test factories), Credo (linting)
