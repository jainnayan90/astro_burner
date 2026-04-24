defmodule AstroBurnerWeb.PageControllerTest do
  use AstroBurnerWeb.ConnCase, async: true

  test "GET / redirects to LiveView", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Spacecraft Mass"
  end
end
