
  defmodule Ticker do
    use GenStage
    require Logger

    def start_link(sleeping_time) do
      {:ok, stage} = GenStage.start_link(__MODULE__, [sleeping_time], name: __MODULE__)
      Logger.debug "#{inspect self()} Ticker #{inspect stage} started."

      {:ok, stage}
    end

    def init(sleeping_time) do
      {:consumer, sleeping_time}
    end

    def handle_subscribe(:producer, options, from, state) do
      Logger.debug "Ticker.handle_subscribe :producer, #{inspect options}, #{inspect from}, #{inspect state}"
      {:automatic, state}
    end

    def handle_subscribe(:consumer, options, from, state) do
      Logger.debug "Ticker.handle_subscribe :consumer, #{inspect options}, #{inspect from}, #{inspect state}"
      {:automatic, state}
    end

    def handle_events(events, _from, sleeping_time) do
      IO.inspect(events)
      Process.sleep(sleeping_time)
      {:noreply, [], sleeping_time}
    end
  end
