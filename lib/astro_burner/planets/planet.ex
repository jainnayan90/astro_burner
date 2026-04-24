defmodule AstroBurner.Planets.Planet do
  @moduledoc "Ecto schema representing a planet and its gravitational constant."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          gravity: Decimal.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "planets" do
    field :name, :string
    field :gravity, :decimal

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(planet, attrs) do
    planet
    |> cast(attrs, [:name, :gravity])
    |> validate_required([:name, :gravity])
    |> validate_number(:gravity, greater_than: 0)
    |> unique_constraint(:name)
  end
end
