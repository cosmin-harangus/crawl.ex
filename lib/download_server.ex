defmodule DownloadServer do
  use Supervisor
  require Logger

  @name DownloadServer

  def start_link do
    Logger.debug "DownloadServer starting..."
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    children = [
      worker(DownloadWorker, [])
    ]

    supervise(children, strategy: :one_for_one)
  end

  def get(url) do
    Logger.debug("DownloadServer.get(#{url})")
    DownloadWorker.get(url)
  end

end
