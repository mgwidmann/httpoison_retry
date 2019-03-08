# HTTPoison Retry

In production, HTTP requests can often fail for random reasons that typically go away if you retry them with enough time inbetween. `HTTPoison.Retry` automatically handles retrying HTTP requests up to a specified number of times and waiting the specified time.

The design intent behind `HTTPoison.Retry` was to stay out of the way and allow the developer to add one simple call in
between where you fetch the data and where you handle the response. This helps to create a barrier wall where failures are
more solidly a failure rather than just a one-time blip that happened for a split second causing a cascade of errors across
your system.

## Installation

The package can be installed by adding `httpoison_retry` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:httpoison_retry, "~> 1.0.0"}
  ]
end
```

## Usage

Simply add a call to `autoretry/2` in between your data fetch call and your handling of the response.

```elixir
HTTPoison.get("https://www.example.com")
# Will retry 5 times waiting 15s between each before returning. Therefore, your process
# could end up waiting up to 75 seconds (plus the request time) on the line below
# Note: below is the same as the defaults
|> autoretry(max_attempts: 5, wait: 15_000, include_404s: false, retry_all_errors: false)
# Your function which will handle the response after success or failed retry
|> handle_response()
```

## Gotchas

Don't forget that the `autoretry/2` call could take a substaintial amount of time to complete. That means usage in the following areas are potential problems:

  * Within a plug/phoenix request
  * Within any `GenServer` process
    * Sleeping for a considerable amount of time leaves the process unable to answer other callers and will result in cascading timeouts of other processes
  * Any Task/Agent call that has a timeout period (i.e. `Task.await/1`)
    * Same reason as `GenServer`s
  * Tests
    * Tests should not be making live HTTP calls anyhow, but if they do this could potentially go over the default 60 seconds in ExUnit.
