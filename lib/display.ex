defmodule Display do
  require Logger
  use GenStage

  def start_link() do
    {:ok, stage} = GenStage.start_link(__MODULE__, [], name: __MODULE__)
    Logger.debug "#{inspect self()} Display #{inspect stage} started."

    {:ok, stage}
  end

  def init([]) do
    {
      :consumer,
      []
    }
  end

  def handle_subscribe(:producer, options, from, state) do
    Logger.debug "Display.handle_subscribe :producer, #{inspect options}, #{inspect from}, #{inspect state}"
    {:automatic, state}
  end

  def handle_subscribe(:consumer, options, from, state) do
    Logger.debug "Display.handle_subscribe :consumer, #{inspect options}, #{inspect from}, #{inspect state}"
    {:automatic, state}
  end

  def handle_events(results, from, state) do
    Logger.debug "Display.handle_events #{inspect results}, #{inspect from}, #{inspect state}"
    {:noreply, [], Enum.concat(state, results)}
  end

  def terminate(reason, state) do
    Logger.debug "Display.terminate #{inspect reason}, #{inspect state}"
    IO.puts "*** results:"

    Tools.render_results(state)
    |> Enum.each(&IO.puts/1)
  end
end
