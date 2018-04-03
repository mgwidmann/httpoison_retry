defmodule HTTPoisonRetry.Mixfile do
  use Mix.Project

  @version "1.0.0"
  def project do
    [
      app: :httpoison_retry,
      version: @version,
      elixir: "~> 1.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      source_url: "git@github.com:mgwidmann/httpoison_retry.git",
      homepage_url: "https://github.com/mgwidmann/httpoison_retry",
      description: "Automatic configurable sleep/retry for HTTPoison requests",
      docs: [
        main: HTTPoison.Retry,
        readme: "README.md"
      ],
      package: package(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 0.13 or ~> 1.0"},
      # Docs
      {:ex_doc, "~> 0.18", only: :dev},
      {:earmark, "~> 1.2", only: :dev},
    ]
  end

  defp package do
    [
      maintainers: ["Matt Widmann"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/mgwidmann/httpoison_retry"}
    ]
  end

  defp aliases do
    [publish: ["hex.publish", "hex.publish docs", "tag"],
     tag: &tag_release/1]
  end

  defp tag_release(_) do
    Mix.shell.info "Tagging release as #{@version}"
    System.cmd("git", ["tag", "-a", "v#{@version}", "-m", "v#{@version}"])
    System.cmd("git", ["push", "--tags"])
  end
end
