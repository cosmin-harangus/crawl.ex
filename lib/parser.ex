defmodule Parser do
  require Logger
  use GenStage

  def start_link(fork_factor) do
    {:ok, stage} = GenStage.start_link(__MODULE__, [fork_factor], name: __MODULE__)
    Logger.debug "#{inspect self()} Parser #{inspect stage} started."

    {:ok, stage}
  end

  def init(fork_factor) do
    {
      :producer_consumer,
      %{
        :fork_factor => fork_factor,
        :buffer => [],
        :subscriptions => []
      }
    }
  end

  def handle_subscribe(:producer, options, from, %{subscriptions: subscriptions} = state) do
    Logger.debug "Parser.handle_subscribe :producer, #{inspect options}, #{inspect from}, #{inspect state}"
    new_state = %{state | subscriptions: [from | subscriptions]}
    {:automatic, new_state}
  end

  def handle_subscribe(:consumer, options, from, state) do
    Logger.debug "Parser.handle_subscribe :consumer, #{inspect options}, #{inspect from}, #{inspect state}"
    {:automatic, state}
  end

  def handle_events(pages, _from, %{buffer: buffer, fork_factor: fork_factor} = state) do
    Logger.debug "Parser.handle_events #{inspect pages}, #{inspect state}"

    buffer =
      pages
      |> Enum.flat_map(fn page -> process_page(page, fork_factor) end)
      |> Enum.concat(buffer)

    state = %{state | buffer: buffer}

    {:noreply, [], state}
  end

  def process_page({current_path, page}, fork_factor) do
    extract_urls(page)
    |> Enum.take_random(fork_factor)
    |> Enum.map(fn u -> {u, current_path} end)
  end

  def extract_urls(%{content_type: content_type, content: content} = page) do
    Logger.debug "Parser.extract_urls #{inspect page}"
    if String.starts_with?(content_type, "text/html") do
      Tools.extract_urls(content)
    else
      []
    end
  end

  #
  # def handle_demand(demand, %{buffer: buffer} = state) do
  #   available = Enum.count(state)
  #   served = min(available, demand)
  #
  #   {pulled, remaining} = state |> Enum.split(served)
  #
  #   new_state =
  #     state
  #     |> Map.put(:buffer, remaining)
  #
  #   {:noreply, pulled, new_state}
  # end
end
