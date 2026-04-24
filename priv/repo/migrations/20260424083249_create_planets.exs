defmodule AstroBurner.Repo.Migrations.CreatePlanets do
  use Ecto.Migration

  def change do
    create table(:planets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :gravity, :decimal, null: false

      timestamps()
    end

    create unique_index(:planets, [:name])
  end
end
