defmodule DownloadServer do
  use Supervisor
  require Logger

  @name DownloadWorker

  ### client API
  def start_link(cookie_jar) do
    Supervisor.start_link(__MODULE__, cookie_jar, name: @name)
  end

  def get(url) do
    {:ok, worker} = Supervisor.start_child(@name, [url, self()])
    Logger.debug("DownloadServer.get(#{url}) sent to #{inspect worker}")
  end

  ### server callbaks
  def init(cookie_jar) do
    spec = [ worker(DownloadWorker, [cookie_jar]) ]

    Supervisor.init(spec, strategy: :simple_one_for_one)
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
