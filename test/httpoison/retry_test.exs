defmodule HTTPoison.RetryTest do
  use ExUnit.Case
  import HTTPoison.Retry
  doctest HTTPoison.Retry

  test "max_attempts" do
    {:ok, agent} = Agent.start fn -> 0 end
    request = fn ->
      Agent.update agent, fn(i) -> i + 1 end
      {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}}
    end
    assert {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}} = autoretry(request.(), max_attempts: 10)
    assert 10 = Agent.get(agent, &(&1))
  end

  test "nxdomain errors" do
    {:ok, agent} = Agent.start fn -> 0 end
    request = fn ->
      Agent.update agent, fn(i) -> i + 1 end
      {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}}
    end
    assert {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}} = autoretry(request.())
    assert 5 = Agent.get(agent, &(&1))
  end

  test "500 errors" do
    {:ok, agent} = Agent.start fn -> 0 end
    request = fn ->
      Agent.update agent, fn(i) -> i + 1 end
      {:ok, %HTTPoison.Response{status_code: 500}}
    end
    assert {:ok, %HTTPoison.Response{status_code: 500}} = autoretry(request.())
    assert 5 = Agent.get(agent, &(&1))
  end

  test "404s by default" do
    {:ok, agent} = Agent.start fn -> 0 end
    request = fn ->
      Agent.update agent, fn(i) -> i + 1 end
      {:ok, %HTTPoison.Response{status_code: 404}}
    end
    assert {:ok, %HTTPoison.Response{status_code: 404}} = autoretry(request.())
    assert 1 = Agent.get(agent, &(&1))
  end

  test "include 404s" do
    {:ok, agent} = Agent.start fn -> 0 end
    request = fn ->
      Agent.update agent, fn(i) -> i + 1 end
      {:ok, %HTTPoison.Response{status_code: 404}}
    end
    assert {:ok, %HTTPoison.Response{status_code: 404}} = autoretry(request.(), include_404s: true)
    assert 5 = Agent.get(agent, &(&1))
  end

  test "successful" do
    {:ok, agent} = Agent.start fn -> 0 end
    request = fn ->
      Agent.update agent, fn(i) -> i + 1 end
      {:ok, %HTTPoison.Response{status_code: 200}}
    end
    assert {:ok, %HTTPoison.Response{status_code: 200}} = autoretry(request.())
    assert 1 = Agent.get(agent, &(&1))
  end

  test "1 failure followed by 1 successful" do
    {:ok, agent} = Agent.start fn -> 0 end
    request = fn ->
      if Agent.get_and_update(agent, fn(i) -> {i + 1, i + 1} end) > 1 do
        {:ok, %HTTPoison.Response{status_code: 200}}
      else
        {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}}
      end
    end
    assert {:ok, %HTTPoison.Response{status_code: 200}} = autoretry(request.())
    assert 2 = Agent.get(agent, &(&1))
  end

  test "4 failures followed by 1 successful" do
    {:ok, agent} = Agent.start fn -> 0 end
    request = fn ->
      if Agent.get_and_update(agent, fn(i) -> {i + 1, i + 1} end) > 4 do
        {:ok, %HTTPoison.Response{status_code: 200}}
      else
        {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}}
      end
    end
    assert {:ok, %HTTPoison.Response{status_code: 200}} = autoretry(request.())
    assert 5 = Agent.get(agent, &(&1))
  end
end
