defmodule AstroBurner.FuelCalculator do
  @moduledoc "Calculates spacecraft fuel requirements for launch and landing maneuvers."

  alias AstroBurner.Planets

  @valid_maneuvers [:launch, :landing]

  @type maneuver :: :launch | :landing

  @doc "Returns the list of supported maneuver types."
  @spec maneuvers() :: [maneuver()]
  def maneuvers, do: @valid_maneuvers

  @doc """
  Calculates the total fuel required for a spacecraft maneuver.

  Fuel itself adds weight, so additional fuel is computed recursively until
  the increment is zero or negative.

  Formulas (result floored to integer):
    launch:  mass * gravity * 0.042 - 33
    landing: mass * gravity * 0.033 - 42
  """
  @spec calculate(pos_integer(), Ecto.UUID.t(), maneuver()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def calculate(mass, planet_id, maneuver)
      when is_integer(mass) and mass > 0 and is_binary(planet_id) and
             maneuver in @valid_maneuvers do
    with {:ok, planet} <- Planets.get_planet(planet_id) do
      total_fuel(mass, planet.gravity, maneuver, 0, nil)
    end
  end

  def calculate(mass, _planet_id, _maneuver) when not is_integer(mass),
    do: {:error, "mass must be an integer"}

  def calculate(mass, _planet_id, _maneuver) when is_integer(mass) and mass <= 0,
    do: {:error, "mass must be greater than zero"}

  def calculate(_mass, planet_id, _maneuver) when not is_binary(planet_id),
    do: {:error, "planet_id must be a string"}

  def calculate(_mass, _planet_id, maneuver) when maneuver not in @valid_maneuvers,
    do: {:error, "maneuver must be :launch or :landing"}

  # gravity is %Decimal{} from the DB; mass is always an integer (initial input
  # or result of a prior fuel_for/3 call). All arithmetic stays in Decimal to
  # preserve the precision stored in the database.
  #
  # tail-recursive via accumulator — safe for arbitrarily large fuel chains.
  # prev_fuel guards against diverging inputs: if an increment exceeds the
  # previous one the series can never converge, so we return an error early.
  defp total_fuel(mass, gravity, maneuver, acc, prev_fuel) do
    case fuel_for(mass, gravity, maneuver) do
      fuel when fuel <= 0 ->
        {:ok, acc}

      fuel when not is_nil(prev_fuel) and fuel >= prev_fuel ->
        {:error, "fuel calculation diverged"}

      fuel ->
        total_fuel(fuel, gravity, maneuver, acc + fuel, fuel)
    end
  end

  defp fuel_for(mass, gravity, :launch) do
    Decimal.new(mass)
    |> Decimal.mult(gravity)
    |> Decimal.mult(Decimal.new("0.042"))
    |> Decimal.sub(Decimal.new("33"))
    |> Decimal.round(0, :floor)
    |> Decimal.to_integer()
  end

  defp fuel_for(mass, gravity, :landing) do
    Decimal.new(mass)
    |> Decimal.mult(gravity)
    |> Decimal.mult(Decimal.new("0.033"))
    |> Decimal.sub(Decimal.new("42"))
    |> Decimal.round(0, :floor)
    |> Decimal.to_integer()
  end
end
