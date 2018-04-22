defmodule DownloadWorker do
  use GenServer
  require Logger

  # Client
  def start_link() do
    Logger.debug "DownloadWorker starting..."
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(_args) do
    {:ok, %{}}
  end

  def get(url) do
    node =
      [Node.self() | Node.list()]
      |> Enum.take_random(1)
      |> Enum.at(0)

    Logger.debug("NODES: #{Node.list()}")
    Logger.debug("Self node: #{Node.self()}")
    Logger.debug("Chosen node: #{node}")
    Logger.debug("Send GET #{url} request to node #{node}")
    :rpc.call(:"#{node}", DownloadWorker, :get, [url, self()])
  end

  # Server (callbacks)
  @http_headers [
    {"Content-Type", "application/x-www-form-urlencoded"},
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:53.0) Gecko/20100101 Firefox/53.0"},
    {"Accept", "text/html"}
  ]

  def handle_cast({:get, url, client}, state) do
    Logger.debug "HTTP GET: url: #{url}"
    {:ok, %HTTPoison.AsyncResponse{id: id}} = HTTPoison.get(url, @http_headers, [{:stream_to, self()}])
    request = %{:url => url, :client => client, :content => <<>>}
    newState = put_in(state, [:in_progress, id],request)
    {:noreply, newState}
  end

  def handle_cast(%HTTPoison.AsyncStatus{id: id, code: code}, state) do
    url = get_in(state, [id, :url])
    Logger.info("HTTP status #{code} received for #{url}")

    if code != 200 do
      parent = get_in(state, [id, :client])

      send(parent, {:page_error, url, "Bad HTTP status #{code}"})

      :hackney.stop_async id

      newState = pop_in(state, [id])

      {:noreply, newState}
    else
      {:noreply, state}
    end

  end

  def handle_cast(%HTTPoison.AsyncHeaders{id: _id, headers: _headers}, state) do
    {:noreply, state}
  end

  def handle_cast(%HTTPoison.AsyncChunk{id: id, chunk: chunk}, state) do
    newState = update_in(state, [id, :content], fn data -> data <> chunk end)
    {:noreply, newState}
  end

  def handle_cast(%HTTPoison.AsyncEnd{id: id}, state) do
    content = get_in(state, [id, :content])
    url = get_in(state, [id, :url])
    client = state[:client]

    Logger.debug("HTTP successful response for url: #{url}")

    send(client, {:page_ok, url, content})

    newState = Map.delete(state, id)

    {:noreply, newState}
  end

  def handle_cast(request, parent) do
    super(request, parent)
  end

end
