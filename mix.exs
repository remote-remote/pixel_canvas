defmodule PixelCanvas.MixProject do
  use Mix.Project

  def project do
    [
      app: :pixel_canvas,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        demo: [
          include_executables_for: [:unix],
          include_erts: true,
          applications: [runtime_tools: :permanent, crypto: :permanent]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :wx, :runtime_tools, :observer],
      mod: {PixelCanvas, []}
    ]
  end

  defp deps do
    []
  end
end
