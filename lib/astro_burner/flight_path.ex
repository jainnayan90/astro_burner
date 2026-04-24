defmodule AstroBurner.FlightPath do
  @moduledoc "Multi-step flight path fuel calculation."

  alias AstroBurner.FuelCalculator
  alias AstroBurner.Planets

  @type step :: %{maneuver: FuelCalculator.maneuver(), planet_id: Ecto.UUID.t()}
  @type step_result :: %{
          maneuver: FuelCalculator.maneuver(),
          planet_id: Ecto.UUID.t(),
          fuel: non_neg_integer()
        }

  @doc "Returns the list of supported maneuver types."
  @spec maneuvers() :: [FuelCalculator.maneuver()]
  defdelegate maneuvers(), to: FuelCalculator

  @doc "Returns all planets ordered alphabetically."
  defdelegate list_planets(), to: Planets

  @doc "Returns the valid maneuvers for the step at `index` given the current `steps`."
  @spec valid_next_maneuvers([step()], non_neg_integer()) :: [FuelCalculator.maneuver()]
  def valid_next_maneuvers(steps, index) do
    case index > 0 && Enum.at(steps, index - 1) do
      %{maneuver: prev} -> Enum.reject(maneuvers(), &(&1 == prev))
      _ -> maneuvers()
    end
  end

  @doc "Returns the required planet ID for the step at `index`, or nil if any planet is valid."
  @spec required_next_planet_id([step()], non_neg_integer()) :: Ecto.UUID.t() | nil
  def required_next_planet_id(steps, index) do
    case index > 0 && Enum.at(steps, index - 1) do
      %{maneuver: :landing, planet_id: planet_id} when not is_nil(planet_id) -> planet_id
      _ -> nil
    end
  end

  @doc """
  Calculates total fuel required for a multi-step flight path.

  Delegates to `calculate_breakdown/2` and returns only the total.
  """
  @spec calculate_total(pos_integer(), [step()]) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def calculate_total(mass, steps) do
    case calculate_breakdown(mass, steps) do
      {:ok, %{total: total}} -> {:ok, total}
      {:error, _} = err -> err
    end
  end

  @doc """
  Calculates total fuel and per-step breakdown for a multi-step flight path.

  Steps are processed in reverse order so that each maneuver accounts for the
  weight of all subsequent fuel. The returned breakdown list is in original
  (forward) step order.
  """
  @spec calculate_breakdown(pos_integer(), [step()]) ::
          {:ok, %{total: non_neg_integer(), breakdown: [step_result()]}}
          | {:error, String.t()}
  def calculate_breakdown(mass, steps)

  def calculate_breakdown(_mass, []), do: {:error, "flight path must have at least one step"}

  def calculate_breakdown(mass, _steps) when not is_integer(mass),
    do: {:error, "mass must be an integer"}

  def calculate_breakdown(mass, _steps) when mass <= 0,
    do: {:error, "mass must be greater than zero"}

  def calculate_breakdown(mass, steps) do
    with :ok <- validate_no_consecutive_maneuvers(steps),
         :ok <- validate_land_launch_same_planet(steps) do
      planets = Planets.get_planets_by_ids(Enum.map(steps, & &1.planet_id))

      steps
      |> Enum.reverse()
      |> Enum.reduce_while({:ok, {0, mass, []}}, &reduce_step(&1, &2, planets))
      |> case do
        {:ok, {total, _mass, breakdown}} -> {:ok, %{total: total, breakdown: breakdown}}
        {:error, _} = err -> err
      end
    end
  end

  defp reduce_step(step, {:ok, {acc_fuel, current_mass, bkd}}, planets) do
    case Map.fetch(planets, step.planet_id) do
      {:ok, planet} ->
        case FuelCalculator.calculate(current_mass, planet, step.maneuver) do
          {:ok, fuel} ->
            entry = %{maneuver: step.maneuver, planet_id: step.planet_id, fuel: fuel}
            {:cont, {:ok, {acc_fuel + fuel, current_mass + fuel, [entry | bkd]}}}

          {:error, _} = err ->
            {:halt, err}
        end

      :error ->
        {:halt, {:error, "planet not found: #{step.planet_id}"}}
    end
  end

  defp validate_no_consecutive_maneuvers(steps) do
    steps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find(fn [a, b] -> a.maneuver == b.maneuver end)
    |> case do
      nil -> :ok
      [a, _] -> {:error, "consecutive #{a.maneuver} steps are not allowed"}
    end
  end

  defp validate_land_launch_same_planet(steps) do
    steps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find(fn [a, b] ->
      a.maneuver == :landing and b.maneuver == :launch and a.planet_id != b.planet_id
    end)
    |> case do
      nil -> :ok
      _ -> {:error, "must launch from the same planet as the preceding landing"}
    end
  end
end
