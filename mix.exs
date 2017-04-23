defmodule Informant.Mixfile do
  use Mix.Project

  @version "~> 1.4"

  def project do
    [app: :informant,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: "Distributes state and events to subscribers",
     package: package(),
     name: "Informant",
     docs: docs()  ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.15", only: :dev}]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      source_url: "https://github.com/ghitchens/informant",
      extras: [ "README.md", "CHANGELOG.md"]
    ]
  end

  defp package do
    [ maintainers: ["Garth Hitchens"],
      licenses: ["Apache-2.0"],
      links: %{github: "https://github.com/ghitchens/informant"},
      files: ~w(lib config) ++ ~w(README.md CHANGELOG.md LICENSE mix.exs) ]
  end
end
