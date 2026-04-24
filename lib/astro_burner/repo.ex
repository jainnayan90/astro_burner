defmodule AstroBurner.Repo do
  use Ecto.Repo,
    otp_app: :astro_burner,
    adapter: Ecto.Adapters.Postgres
end
