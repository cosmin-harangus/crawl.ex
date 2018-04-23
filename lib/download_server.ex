defmodule DownloadServer do
  use Supervisor
  require Logger

  @name DownloadWorker

  def start_link do
    Logger.debug "DownloadServer starting..."
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    jar = CookieJar.new()
    Supervisor.init([DownloadWorker], strategy: :simple_one_for_one)
  end

  def get(url) do
    Logger.debug("DownloadServer.get(#{url})")
    {:ok, worker} = Supervisor.start_child(@name, [])
    GenServer.cast(worker, {:get, url, self()})
  end

  # def get(url) do
  #   node =
  #     [Node.self() | Node.list()]
  #     |> Enum.take_random(1)
  #     |> Enum.at(0)
  #
  #   Logger.debug("NODES: #{Node.list()}")
  #   Logger.debug("Self node: #{Node.self()}")
  #   Logger.debug("Chosen node: #{node}")
  #   Logger.debug("Send GET #{url} request to node #{node}")
  #   Logger.debug("PRocesses: #{inspect(Process.get())}")
  #   :rpc.call(:"#{node}", DownloadWorker, :get, [url, self()])
  # end
end
