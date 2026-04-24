defmodule AstroBurner.PlanetsTest do
  use AstroBurner.DataCase, async: true
  import AstroBurner.Factory

  alias AstroBurner.Planets

  describe "get_planet/1" do
    test "returns {:ok, planet} for a valid planet id" do
      planet = insert(:planet)
      assert {:ok, found} = Planets.get_planet(planet.id)
      assert found.id == planet.id
      assert found.name == planet.name
    end

    test "returns {:error, 'planet not found'} for unknown id" do
      unknown_id = Ecto.UUID.generate()
      assert {:error, "planet not found"} = Planets.get_planet(unknown_id)
    end

    test "returns {:error, 'invalid planet id format'} for malformed id" do
      assert {:error, "invalid planet id format"} = Planets.get_planet("not-a-uuid")
    end

    test "returns {:error, 'planet_id must be a string'} for non-binary id" do
      assert {:error, "planet_id must be a string"} = Planets.get_planet(123)
    end
  end

  describe "list_planets/0" do
    test "returns all planets ordered by name" do
      p1 = insert(:planet)
      p2 = insert(:planet)
      p3 = insert(:planet)

      inserted_names = Enum.sort([p1.name, p2.name, p3.name])
      result_names = Planets.list_planets() |> Enum.map(& &1.name)
      filtered = Enum.filter(result_names, &(&1 in [p1.name, p2.name, p3.name]))
      assert filtered == inserted_names
    end

    test "returns empty list when no planets exist" do
      assert Planets.list_planets() == []
    end
  end
end
