alias AstroBurner.Planets

planets = [
  %{name: "earth", gravity: Decimal.new("9.807")},
  %{name: "moon", gravity: Decimal.new("1.62")},
  %{name: "mars", gravity: Decimal.new("3.711")}
]

Enum.each(planets, &Planets.upsert_planet!/1)
