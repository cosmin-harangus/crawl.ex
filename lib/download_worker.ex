defmodule DownloadWorker do
  use GenServer
  require Logger

  # Client
  def start_link(state) do
    Logger.debug "DownloadWorker starting..."
    GenServer.start_link(__MODULE__, state, [])
  end

  def init(jar) do
    Logger.info("Jar: #{inspect(jar)}")
    {:ok, %{:jar => jar, :requests=> %{}}}
  end

  # Server (callbacks)
  @http_headers [
    {"Content-Type", "application/x-www-form-urlencoded"},
    {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:53.0) Gecko/20100101 Firefox/53.0"},
    {"Accept", "text/html"}
  ]

  def handle_cast({:get, url, client}, state) do
    Logger.debug "HTTP GET: url: #{url}"
    {:ok, %HTTPoison.AsyncResponse{id: id}} = CookieJar.HTTPoison.get(state[:jar], url, @http_headers, [{:stream_to, self()}])
    request = %{:url => url, :client => client, :content => <<>>}
    newState = put_in(state, [:requests, id], request)
    {:noreply, newState}
  end

  def handle_cast(request, parent) do
    super(request, parent)
  end

  def handle_info(%HTTPoison.AsyncStatus{id: id, code: code}, state) do
    url = get_in(state, [:requests, id, :url])
    Logger.info("HTTP status #{code} received for #{url}")

    if code != 200 do
      parent = get_in(state, [:requests, id, :client])

      send(parent, {:page_error, url, "Bad HTTP status #{code}"})

      :hackney.stop_async id

      newState = pop_in(state, [:requests, id])

      {:noreply, newState}
    else
      {:noreply, state}
    end

  end

  def handle_info(%HTTPoison.AsyncHeaders{id: _id, headers: _headers}, state) do
    {:noreply, state}
  end

    # def handle_info(%HTTPoison.AsyncRedirect{id: id, to: redirect_url}, state) do
    #   content = get_in(state, [:requests, id, :content])
    #   url = get_in(state, [:requests, id, :url])
    #   client = get_in(state, [:requests, id, :client])
    #
    #   Logger.debug("HTTP successful response for url: #{url}")
    #
    #   send(client, {:page_redirect, url, redirect_url})
    #
    #   newState = pop_in(state, [:requests, id])
    #
    #   {:noreply, newState}
    # end

  def handle_info(%HTTPoison.AsyncChunk{id: id, chunk: chunk}, state) do
    newState = update_in(state, [:requests, id, :content], fn data -> data <> chunk end)
    {:noreply, newState}
  end

  def handle_info(%HTTPoison.AsyncEnd{id: id}, state) do
    content = get_in(state, [:requests, id, :content])
    url = get_in(state, [:requests, id, :url])
    client = get_in(state, [:requests, id, :client])

    Logger.debug("HTTP successful response for url: #{url}")

    send(client, {:page_ok, url, content})

    newState = pop_in(state, [:requests, id])

    {:noreply, newState}
  end

  def handle_info(request, parent) do
    super(request, parent)
  end
end
