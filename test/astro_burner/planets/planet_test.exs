defmodule AstroBurner.Planets.PlanetTest do
  use AstroBurner.DataCase, async: true
  import AstroBurner.Factory

  alias AstroBurner.Planets.Planet

  describe "changeset/2" do
    test "valid attrs produce a valid changeset" do
      changeset = Planet.changeset(%Planet{}, %{name: "venus", gravity: Decimal.new("8.87")})
      assert changeset.valid?
    end

    test "missing name is invalid" do
      changeset = Planet.changeset(%Planet{}, %{gravity: Decimal.new("9.807")})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "missing gravity is invalid" do
      changeset = Planet.changeset(%Planet{}, %{name: "earth"})
      assert "can't be blank" in errors_on(changeset).gravity
    end

    test "gravity must be greater than 0" do
      changeset = Planet.changeset(%Planet{}, %{name: "earth", gravity: Decimal.new("0")})
      assert "must be greater than 0" in errors_on(changeset).gravity
    end

    test "duplicate name produces a unique_constraint error on insert" do
      insert(:planet, name: "earth")

      {:error, changeset} =
        %Planet{}
        |> Planet.changeset(%{name: "earth", gravity: Decimal.new("9.807")})
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).name
    end
  end
end
