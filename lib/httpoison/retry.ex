defmodule HTTPoison.Retry do
  @moduledoc """
  See `#{__MODULE__}.autoretry/2`
  """

  use Bitwise, only_operators: true

  @max_attempts 5
  @reattempt_wait 15_000
  @doc """
  Takes in a HTTP fetch command and will attempt and reattempt it over and over
  up to a maximum amount without any intervention on behalf of the user.

  Example:

      HTTPoison.get("https://www.example.com")
      # Will retry #{@max_attempts} times waiting #{@reattempt_wait / 1_000}s between each before returning
      # Note: below is the same as the defaults
      |> autoretry(max_attempts: #{@max_attempts}, wait: #{@reattempt_wait}, include_404s: false, retry_unknown_errors: false)
      # Your function which will handle the response after success or the 5 failed retries
      |> handle_response()

  ### Gotcha

  Don't forget that the `autoretry/2` call could take a substaintial amount of time to complete. That means usage in the following areas are potential problems:

    * Within a plug/phoenix request
    * Within any `GenServer` process
      * Sleeping for a considerable amount of time leaves the process unable to answer other callers and will result in cascading timeouts of other processes
    * Any Task/Agent call that has a timeout period (i.e. `Task.await/1`)
      * Same reason as `GenServer`s
    * Tests
      * Tests should not be making live HTTP calls anyhow, but if they do this could potentially go over the default 60 seconds in ExUnit.
  """
  defmacro autoretry(attempt, opts \\ []) do
    quote location: :keep, generated: true do
      HTTPoison.Retry.do_autoretry(fn -> unquote(attempt) end, unquote(opts))
    end
  end

  def do_autoretry(attempt_fn, opts) do
    opts = default_opts()
           |> Keyword.merge(Application.get_all_env(:httpoison_retry))
           |> Keyword.merge(opts)
    do_autoretry(attempt_fn, 1, opts)
  end

  defp do_autoretry(attempt_fn, attempt, opts) do
    case attempt_fn.() do
      # Error conditions
      response = {:error, %HTTPoison.Error{id: nil, reason: reason}} ->
        if reason in opts[:error_reasons] or opts[:retry_unknown_errors] do
          next_attempt(attempt_fn, attempt, opts)
        else
          response
        end

      # OK conditions
      response = {:ok, %HTTPoison.Response{status_code: status_code}} ->
        if status_code in opts[:status_codes] do
          next_attempt(attempt_fn, attempt, opts)
        else
          response
        end

      response ->
        response
    end
  end

  defp next_attempt(attempt_fn, attempt, opts) do
    do_wait(opts[:wait], attempt)

    if opts[:max_attempts] == :infinity || attempt < opts[:max_attempts] - 1 do
      do_autoretry(attempt_fn, attempt + 1, opts)
    else
      attempt_fn.()
    end
  end

  def do_wait(n, _) when is_integer(n), do: Process.sleep(n)
  def do_wait(:exponential, attempt) do
    # This has the potential to sleep for very long times, and should be
    # capped, or the maximum should be controllable
    Process.sleep(:random.uniform(1 <<< attempt) * 1000)
  end

  defp default_opts(), do: [
    max_attempts: @max_attempts,
    wait: @reattempt_wait,
    retry_unknown_errors: false,
    error_reasons: [:nxdomain, :timeout, :closed],
    status_codes: [500],
  ]
end
