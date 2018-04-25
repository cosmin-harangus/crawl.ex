defmodule Feeder do
  require Logger
  use GenStage

  def start_link(max_depth) do
    {:ok, stage} = GenStage.start_link(__MODULE__, [max_depth], name: __MODULE__)
    Logger.debug "#{inspect self()} Parser #{inspect stage} started."

    {:ok, stage}
  end

  def init(max_depth) do
    {
      :producer_consumer,
      %{
        :max_depth => max_depth,
        :visited => MapSet.new,
        :subscriptions => []
      }
    }
  end

  def handle_subscribe(:producer, options, from, %{subscriptions: subscriptions} = state) do
    Logger.debug "Feeder.handle_subscribe :producer, #{inspect options}, #{inspect from}, #{inspect state}"
    new_state = %{state | subscriptions: [from | subscriptions]}
    {:automatic, new_state}
  end

  def handle_subscribe(:consumer, options, from, state) do
    Logger.debug "Feeder.handle_subscribe :consumer, #{inspect options}, #{inspect from}, #{inspect state}"
    {:automatic, state}
  end

  def handle_events(urls, _from, %{visited: visited} = state) do
    Logger.debug "Feeder.handle_events #{inspect urls}, #{inspect state}"
    events =
      urls
      |> Enum.flat_map(fn {url, path} ->
        if is_good_depth(state, path) and is_new_url?(state, url) do
          [url | path]
        else
          []
        end
      end)

    visited =
      urls
      |> Enum.map(fn {u,_p} -> u end)
      |> Enum.into(visited)

    {:noreply, events, %{state | visited: visited}}
  end

  def is_good_depth(%{max_depth: max_depth}, path), do: Enum.count(path) < max_depth - 1

  def is_new_url?(%{visited: visited}, url), do: not(Map.has_key?(visited, url))
end
