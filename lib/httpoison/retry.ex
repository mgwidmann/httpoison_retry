defmodule HTTPoison.Retry do
  @moduledoc """
  See `#{__MODULE__}.autoretry/2`
  """

  @max_attempts 5
  @reattempt_wait 15_000
  @doc """
  Takes in a HTTP fetch command and will attempt and reattempt it over and over
  up to a maximum amount without any intervention on behalf of the user.

  Example:

      HTTPoison.get("https://www.example.com")
      # Will retry #{@max_attempts} times waiting #{@reattempt_wait / 1_000}s between each before returning
      # Note: below is the same as the defaults
      |> autoretry(max_attempts: #{@max_attempts}, wait: #{@reattempt_wait}, include_404s: false)
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
      attempt_fn = fn -> unquote(attempt) end
      opts = Keyword.merge([
        max_attempts: Application.get_env(:httpoison_retry, :max_attempts) || unquote(@max_attempts),
        wait: Application.get_env(:httpoison_retry, :wait) || unquote(@reattempt_wait),
        include_404s: Application.get_env(:httpoison_retry, :include_404s) || false,
        attempt: 1
      ], unquote(opts))
      case attempt_fn.() do
        # Error conditions
        {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}} ->
          HTTPoison.Retry.next_attempt(attempt_fn, opts)
        {:error, %HTTPoison.Error{id: nil, reason: :timeout}} ->
          HTTPoison.Retry.next_attempt(attempt_fn, opts)
        {:error, %HTTPoison.Error{id: nil, reason: :closed}} ->
          HTTPoison.Retry.next_attempt(attempt_fn, opts)
        # OK conditions
        {:ok, %HTTPoison.Response{status_code: 500}} ->
          HTTPoison.Retry.next_attempt(attempt_fn, opts)
        {:ok, %HTTPoison.Response{status_code: 404}} = response ->
          if Keyword.get(opts, :include_404s) do
            HTTPoison.Retry.next_attempt(attempt_fn, opts)
          else
            response
          end
        response ->
          response
      end
    end
  end

  def next_attempt(attempt, opts) do
    Process.sleep(opts[:wait])
    if opts[:max_attempts] == :infinity || opts[:attempt] < opts[:max_attempts] - 1 do
      opts = Keyword.put(opts, :attempt, opts[:attempt] + 1)
      autoretry(attempt.(), opts)
    else
      attempt.()
    end
  end
end
