defmodule DownloadServer do
  use Supervisor
  require Logger

  @name DownloadWorker

  ### client API
  def start_link(cookie_jar) do
    Supervisor.start_link(__MODULE__, cookie_jar, name: @name)
  end

  def get(url, client) do
    Logger.debug "[#{inspect self()}] DownloadServer.get: url=#{url}"

    case Supervisor.start_child(@name, [url, client]) do
      {:ok, worker} ->
        Logger.debug("#{inspect self()} DownloadServer.get: #{url} sent to #{inspect worker}")
      {:error, reason} ->
        send(client, {:page_error, url, reason})
    end
  end

  ### server callbaks
  def init(cookie_jar) do
    spec = [ worker(DownloadWorker, [cookie_jar]) ]

    Supervisor.init(spec, strategy: :simple_one_for_one)
  end

end
