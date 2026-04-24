defmodule AstroBurner.FuelCalculatorTest do
  use AstroBurner.DataCase, async: true
  import AstroBurner.Factory

  alias AstroBurner.FuelCalculator

  setup do
    earth = insert(:planet, name: "earth", gravity: Decimal.new("9.807"))
    moon = insert(:planet, name: "moon", gravity: Decimal.new("1.62"))
    mars = insert(:planet, name: "mars", gravity: Decimal.new("3.711"))
    %{earth: earth, moon: moon, mars: mars}
  end

  describe "calculate/3 landing" do
    test "Apollo 11 CSM (28_801 kg) landing on Earth returns 13_447", %{earth: earth} do
      assert {:ok, 13_447} = FuelCalculator.calculate(28_801, earth.id, :landing)
    end

    test "mass too small to produce positive fuel returns {:ok, 0}", %{earth: earth} do
      # floor(100 * 9.807 * 0.033 - 42) = -10 → no fuel needed
      assert {:ok, 0} = FuelCalculator.calculate(100, earth.id, :landing)
    end

    test "28_801 kg landing on Moon returns 1535", %{moon: moon} do
      assert {:ok, 1535} = FuelCalculator.calculate(28_801, moon.id, :landing)
    end

    test "28_801 kg landing on Mars returns 3874", %{mars: mars} do
      assert {:ok, 3874} = FuelCalculator.calculate(28_801, mars.id, :landing)
    end
  end

  describe "calculate/3 launch" do
    test "28_801 kg launch from Earth returns 19_772", %{earth: earth} do
      assert {:ok, 19_772} = FuelCalculator.calculate(28_801, earth.id, :launch)
    end

    test "1000 kg launch from Earth returns 517", %{earth: earth} do
      assert {:ok, 517} = FuelCalculator.calculate(1000, earth.id, :launch)
    end

    test "28_801 kg launch from Moon returns 2024", %{moon: moon} do
      assert {:ok, 2024} = FuelCalculator.calculate(28_801, moon.id, :launch)
    end

    test "28_801 kg launch from Mars returns 5186", %{mars: mars} do
      assert {:ok, 5186} = FuelCalculator.calculate(28_801, mars.id, :launch)
    end
  end

  describe "calculate/3 errors" do
    test "valid UUID not in DB returns {:error, 'planet not found'}", %{earth: earth} do
      Repo.delete!(earth)
      assert {:error, "planet not found"} = FuelCalculator.calculate(28_801, earth.id, :landing)
    end

    test "malformed planet_id returns {:error, 'invalid planet id format'}" do
      assert {:error, "invalid planet id format"} =
               FuelCalculator.calculate(28_801, "not-a-uuid", :landing)
    end

    test "non-binary planet_id returns {:error, 'planet_id must be a string'}" do
      assert {:error, "planet_id must be a string"} =
               FuelCalculator.calculate(28_801, 123, :landing)
    end

    test "zero mass returns {:error, 'mass must be greater than zero'}", %{earth: earth} do
      assert {:error, "mass must be greater than zero"} =
               FuelCalculator.calculate(0, earth.id, :landing)
    end

    test "negative mass returns {:error, 'mass must be greater than zero'}", %{earth: earth} do
      assert {:error, "mass must be greater than zero"} =
               FuelCalculator.calculate(-100, earth.id, :landing)
    end

    test "float mass returns {:error, 'mass must be an integer'}", %{earth: earth} do
      assert {:error, "mass must be an integer"} =
               FuelCalculator.calculate(28_801.5, earth.id, :landing)
    end

    test "string mass returns {:error, 'mass must be an integer'}", %{earth: earth} do
      assert {:error, "mass must be an integer"} =
               FuelCalculator.calculate("28_801", earth.id, :landing)
    end

    test "invalid maneuver returns {:error, 'maneuver must be :launch or :landing'}", %{
      earth: earth
    } do
      assert {:error, "maneuver must be :launch or :landing"} =
               FuelCalculator.calculate(28_801, earth.id, :orbit)
    end

    test "diverging fuel series returns {:error, 'fuel calculation diverged'}" do
      # gravity=30 → each increment exceeds the last (30 × 0.042 = 1.26 > 1)
      high_g = insert(:planet, name: "high_g", gravity: Decimal.new("30.0"))

      assert {:error, "fuel calculation diverged"} =
               FuelCalculator.calculate(28_801, high_g.id, :launch)
    end
  end

  describe "maneuvers/0" do
    test "returns [:launch, :landing]" do
      assert FuelCalculator.maneuvers() == [:launch, :landing]
    end
  end
end
