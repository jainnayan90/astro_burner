defmodule AstroBurner.FuelCalculatorTest do
  use ExUnit.Case, async: true

  alias AstroBurner.FuelCalculator
  alias AstroBurner.Planets.Planet

  @earth %Planet{gravity: Decimal.new("9.807")}
  @moon %Planet{gravity: Decimal.new("1.62")}
  @mars %Planet{gravity: Decimal.new("3.711")}

  describe "calculate/3 landing" do
    test "Apollo 11 CSM (28_801 kg) landing on Earth returns 13_447" do
      assert {:ok, 13_447} = FuelCalculator.calculate(28_801, @earth, :landing)
    end

    test "mass too small to produce positive fuel returns {:ok, 0}" do
      # floor(100 * 9.807 * 0.033 - 42) = -10 → no fuel needed
      assert {:ok, 0} = FuelCalculator.calculate(100, @earth, :landing)
    end

    test "28_801 kg landing on Moon returns 1535" do
      assert {:ok, 1535} = FuelCalculator.calculate(28_801, @moon, :landing)
    end

    test "28_801 kg landing on Mars returns 3874" do
      assert {:ok, 3874} = FuelCalculator.calculate(28_801, @mars, :landing)
    end
  end

  describe "calculate/3 launch" do
    test "28_801 kg launch from Earth returns 19_772" do
      assert {:ok, 19_772} = FuelCalculator.calculate(28_801, @earth, :launch)
    end

    test "1000 kg launch from Earth returns 517" do
      assert {:ok, 517} = FuelCalculator.calculate(1000, @earth, :launch)
    end

    test "28_801 kg launch from Moon returns 2024" do
      assert {:ok, 2024} = FuelCalculator.calculate(28_801, @moon, :launch)
    end

    test "28_801 kg launch from Mars returns 5186" do
      assert {:ok, 5186} = FuelCalculator.calculate(28_801, @mars, :launch)
    end
  end

  describe "calculate/3 errors" do
    test "zero mass returns {:error, 'mass must be greater than zero'}" do
      assert {:error, "mass must be greater than zero"} =
               FuelCalculator.calculate(0, @earth, :landing)
    end

    test "negative mass returns {:error, 'mass must be greater than zero'}" do
      assert {:error, "mass must be greater than zero"} =
               FuelCalculator.calculate(-100, @earth, :landing)
    end

    test "float mass returns {:error, 'mass must be an integer'}" do
      assert {:error, "mass must be an integer"} =
               FuelCalculator.calculate(28_801.5, @earth, :landing)
    end

    test "string mass returns {:error, 'mass must be an integer'}" do
      assert {:error, "mass must be an integer"} =
               FuelCalculator.calculate("28_801", @earth, :landing)
    end

    test "invalid maneuver returns {:error, 'maneuver must be :launch or :landing'}" do
      assert {:error, "maneuver must be :launch or :landing"} =
               FuelCalculator.calculate(28_801, @earth, :orbit)
    end

    test "diverging fuel series returns {:error, 'fuel calculation diverged'}" do
      # gravity=30 → each increment exceeds the last (30 × 0.042 = 1.26 > 1)
      high_g = %Planet{gravity: Decimal.new("30.0")}

      assert {:error, "fuel calculation diverged"} =
               FuelCalculator.calculate(28_801, high_g, :launch)
    end
  end

  describe "maneuvers/0" do
    test "returns [:launch, :landing]" do
      assert FuelCalculator.maneuvers() == [:launch, :landing]
    end
  end
end
