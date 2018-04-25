defmodule Downloader do
  require CookieJar
  require Logger
  use GenStage

  def start_link() do
    {:ok, stage} = GenStage.start_link(__MODULE__, [], name: __MODULE__)
    Logger.debug "#{inspect self()} Downloader #{inspect stage} started."

    {:ok, stage}
  end

  def init(_) do
    {
      :producer_consumer,
      %{
        :buffer => [],
        :downloads_pending => %{},
        :subscriptions => [],
        :demand_left => 0
      }
    }
  end

  def download(pid, url) do
    GenStage.cast(pid, {:download, url})
  end

  def handle_subscribe(:producer, options, from, %{subscriptions: subscriptions} = state) do
    Logger.debug "Downloader.handle_subscribe :producer, #{inspect options}, #{inspect from}, #{inspect state}"
    new_state = %{state | subscriptions: [from | subscriptions]}
    {:automatic, new_state}
  end

  def handle_subscribe(:consumer, options, from, state) do
    Logger.debug "Downloader.handle_subscribe :consumer, #{inspect options}, #{inspect from}, #{inspect state}"
    {:automatic, state}
  end

  def handle_demand(demand, %{buffer: buffer} = state) do
    Logger.debug "Downloader.handle_demand #{inspect demand}, #{inspect state}"
    available = Enum.count(buffer)
    served = min(available, demand)

    {pulled, remaining} = buffer |> Enum.split(served)

    {
      :noreply,
      pulled,
      %{state|
        buffer: remaining,
        demand_left: max(0, demand - available)
      }
    }
  end

  def handle_events(jobs, _from, %{downloads_pending: downloads_pending} = state) do
    Logger.debug "Downloader.events #{inspect jobs}, #{inspect state}"

    jobs
    |> Enum.each(fn {url, _path} -> download(url) end)

    downloads_pending = Enum.into(jobs, downloads_pending)

    {:noreply, [], %{state | downloads_pending: downloads_pending}}
  end

  def handle_cast({:download, url}, state) do
    Logger.debug "Downloader.handle_cast #{inspect url}, #{inspect state}"
    handle_events([{url, []}], self(), state)
  end

  def handle_info({:page_ok, url, response} = msg, %{buffer: buffer, downloads_pending: downloads_pending} = state) do
    Logger.debug "Downloader.handle_info :page_ok #{inspect msg}, #{inspect state}"
    path = downloads_pending[url]
    
    state =
      %{ state |
        downloads_pending: Map.delete(downloads_pending, url),
        buffer:  Enum.concat(buffer, [{[url | path], response}])
      }
    handle_demand(state[:demand_left], state)
  end

  def handle_info({:page_error, url, reason}, %{downloads_pending: downloads_pending} = state) do
    Logger.debug "Downloader.handle_info :page_error, #{inspect url}, #{inspect reason} #{inspect state}"

    state = %{state |
      downloads_pending: Map.delete(downloads_pending, url)
    }

    {:noreply, [], state}
  end


  defp download(url) do
    Logger.debug "[#{inspect self()}] download url=#{url}"
    DownloadServer.get(url, self())
    # node =
    #   [Node.self() | Node.list()]
    #   |> Enum.take_random(1)
    #   |> Enum.at(0)
    #
    # :rpc.call(:"#{node}", DownloadServer, :get, [url, self()])
  end
end
