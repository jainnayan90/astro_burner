defmodule AstroBurnerWeb.PageController do
  use AstroBurnerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
