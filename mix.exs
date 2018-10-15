defmodule TelegramApiJson.MixProject do
  use Mix.Project

  def project do
    [
      app: :telegram_api_json,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.3.0"},
      {:poison, "~> 4.0"},
      {:floki, "~> 0.20.0"}
    ]
  end
end
