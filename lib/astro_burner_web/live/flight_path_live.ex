defmodule AstroBurnerWeb.FlightPathLive do
  @moduledoc "LiveView for building a multi-step flight path and calculating total fuel."

  use AstroBurnerWeb, :live_view

  alias AstroBurner.FlightPath

  @impl true
  def mount(_params, _session, socket) do
    planets = if connected?(socket), do: FlightPath.list_planets(), else: []

    socket =
      assign(socket,
        planets: planets,
        mass_form: to_form(%{"mass" => ""}),
        mass: nil,
        mass_error: nil,
        steps: [],
        next_step_id: 0,
        result: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate-mass", %{"mass" => raw}, socket) do
    {mass, mass_error} =
      case Integer.parse(raw) do
        {mass, ""} when mass > 0 -> {mass, nil}
        {_mass, ""} -> {nil, "Mass must be greater than zero"}
        _ -> {nil, if(raw == "", do: nil, else: "Mass must be a positive whole number")}
      end

    socket =
      socket
      |> assign(mass_form: to_form(%{"mass" => raw}), mass: mass, mass_error: mass_error)
      |> recalculate()

    {:noreply, socket}
  end

  def handle_event("add-step", _params, socket) do
    next_step_id = socket.assigns.next_step_id + 1
    new_step = build_step(next_step_id, :launch, nil)
    steps = socket.assigns.steps ++ [new_step]

    socket =
      socket
      |> assign(next_step_id: next_step_id, steps: steps)
      |> recalculate()

    {:noreply, socket}
  end

  def handle_event("remove-step", %{"id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, ""} ->
        steps = Enum.reject(socket.assigns.steps, &(&1.id == id))

        socket =
          socket
          |> assign(steps: steps)
          |> recalculate()

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("remove-step", _params, socket), do: {:noreply, socket}

  def handle_event(
        "validate-step",
        %{"step_id" => id_str, "maneuver" => maneuver_str} = params,
        socket
      )
      when maneuver_str in ~w(launch landing) do
    case Integer.parse(id_str) do
      {id, ""} ->
        maneuver = String.to_existing_atom(maneuver_str)
        planet_id = params["planet_id"] |> empty_to_nil()

        steps =
          Enum.map(socket.assigns.steps, fn
            %{id: ^id} = step -> build_step(step.id, maneuver, planet_id)
            step -> step
          end)

        socket =
          socket
          |> assign(steps: steps)
          |> recalculate()

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("validate-step", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mb-6">
        <h1 class="text-3xl font-bold">AstroBurner</h1>
        <p class="text-base-content/60 mt-1">
          Calculate fuel requirements for multi-step space missions
        </p>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
        <%!-- Left column: inputs --%>
        <div class="space-y-6">
          <%!-- Spacecraft Mass card --%>
          <div class="card bg-base-200">
            <div class="card-body">
              <h2 class="card-title">Spacecraft Mass</h2>
              <.form for={@mass_form} id="mass-form" phx-change="validate-mass">
                <.input
                  field={@mass_form[:mass]}
                  id="mass-input"
                  type="number"
                  label="Mass (kg)"
                  placeholder="e.g. 28801"
                  min="1"
                />
              </.form>
              <div
                :if={@mass_error}
                id="mass-error"
                role="alert"
                class="alert alert-error alert-soft"
              >
                <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
                <span>{@mass_error}</span>
              </div>
            </div>
          </div>

          <%!-- Flight Path card --%>
          <div class="card bg-base-200">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title">Flight Path</h2>
                <.button
                  id="add-step-btn"
                  phx-click="add-step"
                  class="btn btn-sm btn-primary"
                  disabled={is_nil(@mass)}
                >
                  <.icon name="hero-plus" class="size-4" /> Add Step
                </.button>
              </div>

              <%= if @steps == [] do %>
                <p class="text-sm text-base-content/50 py-4 text-center">
                  No steps yet — click "Add Step" to build your flight path.
                </p>
              <% else %>
                <div class="space-y-3 mt-2">
                  <%= for {step, index} <- @steps |> Enum.with_index() |> Enum.reverse() do %>
                    <% available_planets = available_planets_for(@steps, index, @planets) %>
                    <% available_maneuvers = available_maneuvers_for(@steps, index) %>
                    <div class="flex items-end gap-3">
                      <.form
                        for={step.form}
                        id={"step-form-#{step.id}"}
                        phx-change="validate-step"
                        class="flex-1"
                      >
                        <.input type="hidden" field={step.form[:step_id]} id={"step_id_#{step.id}"} />
                        <div class="grid grid-cols-2 gap-3">
                          <.input
                            field={step.form[:maneuver]}
                            id={"maneuver_#{step.id}"}
                            type="select"
                            label="Action"
                            options={available_maneuvers}
                          />
                          <.input
                            field={step.form[:planet_id]}
                            id={"planet_id_#{step.id}"}
                            type="select"
                            label="Planet"
                            prompt="Select planet…"
                            options={
                              Enum.map(available_planets, &{String.capitalize(&1.name), &1.id})
                            }
                          />
                        </div>
                      </.form>
                      <.button
                        :if={index == length(@steps) - 1}
                        id={"remove-step-#{step.id}"}
                        phx-click="remove-step"
                        phx-value-id={step.id}
                        class="btn btn-sm btn-ghost text-error mb-2"
                        aria-label="Remove step"
                      >
                        <.icon name="hero-trash" class="size-4" />
                      </.button>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Right column: results --%>
        <div>
          <%= cond do %>
            <% is_nil(@result) -> %>
              <div class="card bg-base-200 h-full">
                <div class="card-body items-center justify-center text-center py-16">
                  <.icon name="hero-rocket-launch" class="size-12 text-base-content/30 mb-4" />
                  <p class="text-base-content/50">
                    Enter spacecraft mass and add flight path steps to see fuel requirements.
                  </p>
                </div>
              </div>
            <% match?({:error, _}, @result) -> %>
              <% {:error, reason} = @result %>
              <div id="fuel-result" role="alert" class="alert alert-error">
                <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
                <span>Calculation error: {reason}</span>
              </div>
            <% true -> %>
              <% {:ok, %{total: total, breakdown: breakdown}} = @result %>
              <div id="fuel-result" class="card bg-base-200">
                <div class="card-body">
                  <div class="stats bg-primary text-primary-content w-full shadow mb-2">
                    <div class="stat">
                      <div class="stat-title text-primary-content/70">Total Fuel Required</div>
                      <div class="stat-value">{format_number(total)} kg</div>
                    </div>
                  </div>
                  <div class="divider">Step Breakdown</div>
                  <.table id="breakdown-table" rows={breakdown}>
                    <:col :let={row} label="Action">{format_maneuver(row.maneuver)}</:col>
                    <:col :let={row} label="Planet">{planet_name(row.planet_id, @planets)}</:col>
                    <:col :let={row} label="Fuel (kg)">{format_number(row.fuel)}</:col>
                  </.table>
                </div>
              </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp build_step(id, maneuver, planet_id) do
    form =
      to_form(%{
        "step_id" => to_string(id),
        "maneuver" => to_string(maneuver),
        "planet_id" => planet_id || ""
      })

    %{id: id, maneuver: maneuver, planet_id: planet_id, form: form}
  end

  defp available_maneuvers_for(steps, index) do
    steps
    |> FlightPath.valid_next_maneuvers(index)
    |> Enum.map(&{&1 |> to_string() |> String.capitalize(), to_string(&1)})
  end

  defp available_planets_for(steps, index, planets) do
    case FlightPath.required_next_planet_id(steps, index) do
      nil -> planets
      planet_id -> Enum.filter(planets, &(&1.id == planet_id))
    end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp format_maneuver(:launch), do: "Launch"
  defp format_maneuver(:landing), do: "Land"

  defp planet_name(planet_id, planets) do
    case Enum.find(planets, &(&1.id == planet_id)) do
      nil -> planet_id
      planet -> String.capitalize(planet.name)
    end
  end

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp recalculate(socket) do
    %{mass: mass, steps: steps} = socket.assigns

    cond do
      is_nil(mass) ->
        assign(socket, :result, nil)

      steps == [] ->
        assign(socket, :result, nil)

      Enum.any?(steps, &is_nil(&1.planet_id)) ->
        # An incomplete step is being filled — keep the last valid result visible
        socket

      true ->
        assign(socket, :result, FlightPath.calculate_breakdown(mass, steps))
    end
  end
end
