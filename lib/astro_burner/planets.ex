defmodule AstroBurner.Planets do
  @moduledoc "Manages planet data used for fuel calculations."

  import Ecto.Query

  alias AstroBurner.Planets.Planet
  alias AstroBurner.Repo

  @doc "Fetches a planet by UUID string. Returns `{:error, _}` for unknown, malformed, or non-string IDs."
  @spec get_planet(Ecto.UUID.t()) :: {:ok, Planet.t()} | {:error, String.t()}
  def get_planet(id) when is_binary(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Planet{} = planet <- Repo.get(Planet, uuid) do
      {:ok, planet}
    else
      :error -> {:error, "invalid planet id format"}
      nil -> {:error, "planet not found"}
    end
  end

  def get_planet(_id), do: {:error, "planet_id must be a string"}

  @doc "Inserts a planet from `attrs`. Skips silently if a planet with the same name already exists."
  @spec upsert_planet!(map()) :: Planet.t()
  def upsert_planet!(attrs) do
    %Planet{}
    |> Planet.changeset(attrs)
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :name)
  end

  @doc "Returns all planets ordered alphabetically by name."
  @spec list_planets() :: [Planet.t()]
  def list_planets, do: Repo.all(from p in Planet, order_by: p.name)
end
