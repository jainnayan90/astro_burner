defmodule AstroBurner.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: AstroBurner.Repo

  alias AstroBurner.Planets.Planet

  def planet_factory do
    %Planet{
      name: sequence(:name, &"planet_#{&1}"),
      gravity: Decimal.new("9.807")
    }
  end
end
