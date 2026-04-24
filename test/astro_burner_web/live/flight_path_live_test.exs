defmodule AstroBurnerWeb.FlightPathLiveTest do
  use AstroBurnerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import AstroBurner.Factory

  describe "mount" do
    test "renders mass input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#mass-input")
    end

    test "renders add step button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#add-step-btn")
    end

    test "add step button is disabled before mass is entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#add-step-btn[disabled]")
    end

    test "does not show fuel result on initial load", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      refute has_element?(view, "#fuel-result")
    end
  end

  describe "flight path building" do
    setup %{conn: conn} do
      earth = insert(:planet, name: "Earth", gravity: Decimal.new("9.807"))
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})
      %{view: view, earth: earth}
    end

    test "clicking add step renders a step row", %{view: view} do
      view |> element("#add-step-btn") |> render_click()
      assert has_element?(view, "#step-form-1")
    end

    test "clicking add step twice renders two step rows", %{view: view} do
      view |> element("#add-step-btn") |> render_click()
      view |> element("#add-step-btn") |> render_click()
      assert has_element?(view, "#step-form-1")
      assert has_element?(view, "#step-form-2")
    end

    test "clicking remove button removes the step row", %{view: view} do
      view |> element("#add-step-btn") |> render_click()
      assert has_element?(view, "#step-form-1")
      view |> element("#remove-step-1") |> render_click()
      refute has_element?(view, "#step-form-1")
    end

    test "removing one step leaves others intact", %{view: view} do
      view |> element("#add-step-btn") |> render_click()
      view |> element("#add-step-btn") |> render_click()
      view |> element("#remove-step-2") |> render_click()
      refute has_element?(view, "#step-form-2")
      assert has_element?(view, "#step-form-1")
    end

    test "updating step maneuver keeps the row", %{view: view, earth: earth} do
      view |> element("#add-step-btn") |> render_click()

      view
      |> element("#step-form-1")
      |> render_change(%{"step_id" => "1", "maneuver" => "landing", "planet_id" => earth.id})

      assert has_element?(view, "#step-form-1")
    end

    test "remove button is absent on non-last steps", %{view: view} do
      view |> element("#add-step-btn") |> render_click()
      view |> element("#add-step-btn") |> render_click()

      refute has_element?(view, "#remove-step-1")
      assert has_element?(view, "#remove-step-2")
    end
  end

  describe "calculation" do
    setup do
      earth = insert(:planet, name: "Earth", gravity: Decimal.new("9.807"))
      moon = insert(:planet, name: "Moon", gravity: Decimal.new("1.62"))
      %{earth: earth, moon: moon}
    end

    test "result is preserved when an incomplete step is added", %{conn: conn, earth: earth} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})
      view |> element("#add-step-btn") |> render_click()

      view
      |> element("#step-form-1")
      |> render_change(%{"step_id" => "1", "maneuver" => "launch", "planet_id" => earth.id})

      assert has_element?(view, "#fuel-result")

      view |> element("#add-step-btn") |> render_click()

      assert has_element?(view, "#fuel-result")
    end

    test "shows fuel result when mass and all steps are valid", %{conn: conn, earth: earth} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})
      view |> element("#add-step-btn") |> render_click()

      view
      |> element("#step-form-1")
      |> render_change(%{"step_id" => "1", "maneuver" => "launch", "planet_id" => earth.id})

      assert has_element?(view, "#fuel-result")
    end

    test "Apollo 11 mission shows 51898 kg", %{conn: conn, earth: earth, moon: moon} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})

      for _ <- 1..4 do
        view |> element("#add-step-btn") |> render_click()
      end

      view
      |> element("#step-form-1")
      |> render_change(%{"step_id" => "1", "maneuver" => "launch", "planet_id" => earth.id})

      view
      |> element("#step-form-2")
      |> render_change(%{"step_id" => "2", "maneuver" => "landing", "planet_id" => moon.id})

      view
      |> element("#step-form-3")
      |> render_change(%{"step_id" => "3", "maneuver" => "launch", "planet_id" => moon.id})

      view
      |> element("#step-form-4")
      |> render_change(%{"step_id" => "4", "maneuver" => "landing", "planet_id" => earth.id})

      view
      |> element("#mass-form")
      |> render_change(%{"mass" => "28801"})

      assert has_element?(view, "#fuel-result")
      assert view |> element("#fuel-result") |> render() =~ "51,898"
    end

    test "no result when a step has no planet selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})
      view |> element("#add-step-btn") |> render_click()

      refute has_element?(view, "#fuel-result")
    end

    test "no result when steps list is empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#mass-form")
      |> render_change(%{"mass" => "28801"})

      refute has_element?(view, "#fuel-result")
    end

    test "shows error for consecutive same maneuver steps", %{
      conn: conn,
      earth: earth,
      moon: moon
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})
      view |> element("#add-step-btn") |> render_click()
      view |> element("#add-step-btn") |> render_click()

      view
      |> element("#step-form-1")
      |> render_change(%{"step_id" => "1", "maneuver" => "launch", "planet_id" => earth.id})

      view
      |> element("#step-form-2")
      |> render_change(%{"step_id" => "2", "maneuver" => "launch", "planet_id" => moon.id})

      assert view |> element("#fuel-result") |> render() =~ "launch"
    end

    test "shows error for land then launch on different planet", %{
      conn: conn,
      earth: earth,
      moon: moon
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})
      view |> element("#add-step-btn") |> render_click()
      view |> element("#add-step-btn") |> render_click()

      view
      |> element("#step-form-1")
      |> render_change(%{"step_id" => "1", "maneuver" => "landing", "planet_id" => moon.id})

      view
      |> element("#step-form-2")
      |> render_change(%{"step_id" => "2", "maneuver" => "launch", "planet_id" => earth.id})

      assert view |> element("#fuel-result") |> render() =~ "same planet"
    end

    test "shows mass error for non-numeric input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#mass-form")
      |> render_change(%{"mass" => "abc"})

      assert has_element?(view, "#mass-error")
    end

    test "shows mass error for zero mass", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#mass-form")
      |> render_change(%{"mass" => "0"})

      assert has_element?(view, "#mass-error")
    end

    test "clears mass error when valid mass entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#mass-form") |> render_change(%{"mass" => "abc"})
      assert has_element?(view, "#mass-error")

      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})
      refute has_element?(view, "#mass-error")
    end
  end

  describe "dropdown filtering" do
    setup %{conn: conn} do
      earth = insert(:planet, name: "Earth", gravity: Decimal.new("9.807"))
      moon = insert(:planet, name: "Moon", gravity: Decimal.new("1.62"))
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("#mass-form") |> render_change(%{"mass" => "28801"})
      %{view: view, earth: earth, moon: moon}
    end

    test "first step has both maneuvers available", %{view: view} do
      view |> element("#add-step-btn") |> render_click()

      assert has_element?(view, "#maneuver_1 option[value='launch']")
      assert has_element?(view, "#maneuver_1 option[value='landing']")
    end

    test "second step shows only landing after a launch", %{view: view, earth: earth} do
      view |> element("#add-step-btn") |> render_click()

      view
      |> element("#step-form-1")
      |> render_change(%{"step_id" => "1", "maneuver" => "launch", "planet_id" => earth.id})

      view |> element("#add-step-btn") |> render_click()

      assert has_element?(view, "#maneuver_2 option[value='landing']")
      refute has_element?(view, "#maneuver_2 option[value='launch']")
    end

    test "second step planet is restricted after landing on a planet", %{
      view: view,
      earth: earth,
      moon: moon
    } do
      view |> element("#add-step-btn") |> render_click()

      view
      |> element("#step-form-1")
      |> render_change(%{"step_id" => "1", "maneuver" => "landing", "planet_id" => moon.id})

      view |> element("#add-step-btn") |> render_click()

      assert has_element?(view, "#planet_id_2 option[value='#{moon.id}']")
      refute has_element?(view, "#planet_id_2 option[value='#{earth.id}']")
    end
  end
end
