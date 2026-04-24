defmodule AstroBurner.FlightPathTest do
  use AstroBurner.DataCase, async: true
  import AstroBurner.Factory

  alias AstroBurner.FlightPath

  describe "calculate_total/2" do
    setup do
      earth = insert(:planet, name: "Earth", gravity: Decimal.new("9.807"))
      moon = insert(:planet, name: "Moon", gravity: Decimal.new("1.62"))
      mars = insert(:planet, name: "Mars", gravity: Decimal.new("3.711"))
      %{earth: earth, moon: moon, mars: mars}
    end

    test "Apollo 11 mission returns 51898", %{earth: earth, moon: moon} do
      steps = [
        %{maneuver: :launch, planet_id: earth.id},
        %{maneuver: :landing, planet_id: moon.id},
        %{maneuver: :launch, planet_id: moon.id},
        %{maneuver: :landing, planet_id: earth.id}
      ]

      assert {:ok, 51_898} = FlightPath.calculate_total(28_801, steps)
    end

    test "Mars mission returns 33388", %{earth: earth, mars: mars} do
      steps = [
        %{maneuver: :launch, planet_id: earth.id},
        %{maneuver: :landing, planet_id: mars.id},
        %{maneuver: :launch, planet_id: mars.id},
        %{maneuver: :landing, planet_id: earth.id}
      ]

      assert {:ok, 33_388} = FlightPath.calculate_total(14_606, steps)
    end

    test "Passenger Ship mission returns 212161", %{earth: earth, moon: moon, mars: mars} do
      steps = [
        %{maneuver: :launch, planet_id: earth.id},
        %{maneuver: :landing, planet_id: moon.id},
        %{maneuver: :launch, planet_id: moon.id},
        %{maneuver: :landing, planet_id: mars.id},
        %{maneuver: :launch, planet_id: mars.id},
        %{maneuver: :landing, planet_id: earth.id}
      ]

      assert {:ok, 212_161} = FlightPath.calculate_total(75_432, steps)
    end

    test "single step returns correct fuel", %{earth: earth} do
      steps = [%{maneuver: :launch, planet_id: earth.id}]
      assert {:ok, 19_772} = FlightPath.calculate_total(28_801, steps)
    end

    test "empty steps returns error" do
      assert {:error, _} = FlightPath.calculate_total(28_801, [])
    end

    test "zero mass returns error", %{earth: earth} do
      steps = [%{maneuver: :launch, planet_id: earth.id}]
      assert {:error, _} = FlightPath.calculate_total(0, steps)
    end

    test "negative mass returns error", %{earth: earth} do
      steps = [%{maneuver: :launch, planet_id: earth.id}]
      assert {:error, _} = FlightPath.calculate_total(-100, steps)
    end

    test "non-integer mass returns error", %{earth: earth} do
      steps = [%{maneuver: :launch, planet_id: earth.id}]
      assert {:error, _} = FlightPath.calculate_total(28_801.5, steps)
    end

    test "consecutive launch steps return error", %{earth: earth, moon: moon} do
      steps = [
        %{maneuver: :launch, planet_id: earth.id},
        %{maneuver: :launch, planet_id: moon.id}
      ]

      assert {:error, msg} = FlightPath.calculate_total(28_801, steps)
      assert msg =~ "launch"
    end

    test "consecutive landing steps return error", %{earth: earth, moon: moon} do
      steps = [
        %{maneuver: :landing, planet_id: moon.id},
        %{maneuver: :landing, planet_id: earth.id}
      ]

      assert {:error, msg} = FlightPath.calculate_total(28_801, steps)
      assert msg =~ "landing"
    end

    test "landing then launch on different planet returns error", %{earth: earth, moon: moon} do
      steps = [
        %{maneuver: :landing, planet_id: moon.id},
        %{maneuver: :launch, planet_id: earth.id}
      ]

      assert {:error, msg} = FlightPath.calculate_total(28_801, steps)
      assert msg =~ "same planet"
    end

    test "invalid planet_id in a step returns error" do
      steps = [%{maneuver: :launch, planet_id: "00000000-0000-0000-0000-000000000000"}]
      assert {:error, _} = FlightPath.calculate_total(28_801, steps)
    end
  end

  describe "calculate_breakdown/2" do
    setup do
      earth = insert(:planet, name: "Earth", gravity: Decimal.new("9.807"))
      moon = insert(:planet, name: "Moon", gravity: Decimal.new("1.62"))
      %{earth: earth, moon: moon}
    end

    test "returns per-step fuel breakdown in forward order", %{earth: earth, moon: moon} do
      steps = [
        %{maneuver: :launch, planet_id: earth.id},
        %{maneuver: :landing, planet_id: moon.id}
      ]

      assert {:ok, %{total: total, breakdown: breakdown}} =
               FlightPath.calculate_breakdown(28_801, steps)

      assert length(breakdown) == 2
      [step1, step2] = breakdown
      assert step1.maneuver == :launch
      assert step1.planet_id == earth.id
      assert is_integer(step1.fuel) and step1.fuel > 0
      assert step2.maneuver == :landing
      assert step2.planet_id == moon.id
      assert is_integer(step2.fuel) and step2.fuel > 0
      assert total == step1.fuel + step2.fuel
    end

    test "Apollo 11 breakdown sums to total", %{earth: earth, moon: moon} do
      steps = [
        %{maneuver: :launch, planet_id: earth.id},
        %{maneuver: :landing, planet_id: moon.id},
        %{maneuver: :launch, planet_id: moon.id},
        %{maneuver: :landing, planet_id: earth.id}
      ]

      assert {:ok, %{total: 51_898, breakdown: breakdown}} =
               FlightPath.calculate_breakdown(28_801, steps)

      assert length(breakdown) == 4
      assert Enum.sum(Enum.map(breakdown, & &1.fuel)) == 51_898
    end

    test "each step's fuel is positive", %{earth: earth, moon: moon} do
      steps = [
        %{maneuver: :launch, planet_id: earth.id},
        %{maneuver: :landing, planet_id: moon.id}
      ]

      assert {:ok, %{breakdown: breakdown}} = FlightPath.calculate_breakdown(28_801, steps)
      assert Enum.all?(breakdown, &(&1.fuel > 0))
    end
  end

  describe "valid_next_maneuvers/2" do
    test "first step returns all maneuvers" do
      assert FlightPath.valid_next_maneuvers([], 0) == [:launch, :landing]
    end

    test "after a launch step, only landing is allowed" do
      steps = [%{maneuver: :launch, planet_id: nil}]
      assert FlightPath.valid_next_maneuvers(steps, 1) == [:landing]
    end

    test "after a landing step, only launch is allowed" do
      steps = [%{maneuver: :landing, planet_id: nil}]
      assert FlightPath.valid_next_maneuvers(steps, 1) == [:launch]
    end
  end

  describe "required_next_planet_id/2" do
    test "returns nil for the first step" do
      assert is_nil(FlightPath.required_next_planet_id([], 0))
    end

    test "returns nil when preceding step is a launch" do
      steps = [%{maneuver: :launch, planet_id: "some-id"}]
      assert is_nil(FlightPath.required_next_planet_id(steps, 1))
    end

    test "returns the planet_id when preceding step is a landing" do
      steps = [%{maneuver: :landing, planet_id: "moon-uuid"}]
      assert FlightPath.required_next_planet_id(steps, 1) == "moon-uuid"
    end

    test "returns nil when preceding landing has no planet selected" do
      steps = [%{maneuver: :landing, planet_id: nil}]
      assert is_nil(FlightPath.required_next_planet_id(steps, 1))
    end
  end
end
