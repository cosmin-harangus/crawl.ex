defmodule DownloadWorker do
  use GenServer
  require CookieJar
  require Logger

  ### Client
  def start_link(cookie_jar , url, client) do
    {:ok, worker} = GenServer.start_link(__MODULE__, [cookie_jar, url, client], [])
    Logger.debug "#{inspect self()} DownloadWorker #{inspect worker} started with cookie jar:#{inspect cookie_jar}, url:#{url}, client:#{inspect client}"

    {:ok, worker}
  end

  ### Server (callbacks)
  def init([cookie_jar, url, client]) do
    cookies = CookieJar.label(cookie_jar)

    headers = make_headers(cookies)

    case HTTPoison.get(url, headers, [{:stream_to, self()}]) do
      {:ok, %HTTPoison.AsyncResponse{id: id}} ->
        Logger.debug "#{inspect self()} HTTP GET: id=#{inspect id}, url=#{url}, cookies=#{cookies}, worker=#{inspect self()}"

        {
          :ok,
          %{
            :cookie_jar => cookie_jar,
            :client => client,
            :url => url,
            :status => nil,
            :content_type => nil,
            :content => <<>>
          }
        }
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_cast(request, parent) do
    super(request, parent)
  end

  def handle_info(%HTTPoison.AsyncStatus{id: id, code: code}, %{url: url} = state) do
    Logger.debug "#{inspect self()} DownloadWorker.handle_info: AsyncStatus(#{inspect id}, 200) for url: #{url}"

    newState = Map.put(state, :status, code)

    {:noreply, newState}
  end

  # def handle_info(%HTTPoison.AsyncStatus{id: id, code: code}, {url: url, client: client}) do
  #   Logger.debug "DownloadWorker.handle_info: AsyncStatus(#{inspect id}, #{inspect code}). State = #{inspect state}"
  #   Logger.info("HTTP status #{code} received for #{url}")
  #
  #   if code >= 400 do
  #
  #     send(parent, {:page_error, url, "Bad HTTP status #{code}"})
  #
  #     :hackney.stop_async id
  #
  #     Logger.debug "newState=#{inspect newState}"
  #     {:noreply, newState}
  #   else
  #     {:noreply, state}
  #   end
  #
  # end

  def handle_info(%HTTPoison.AsyncHeaders{id: id, headers: headers}, %{cookie_jar: cookie_jar} = state) do
    Logger.debug "#{inspect self()} DownloadWorker.handle_info: AsyncHeaders: id=#{inspect id}, \n*** Headers=#{inspect headers},\n*** State = #{inspect state}"

    cookies = Tools.extract_cookies(headers)

    Logger.debug "#{inspect self()} Pour cookies in the jar: #{inspect cookies}"

    CookieJar.pour(cookie_jar, cookies)

    newState = Map.put(state, :content_type, Tools.content_type(headers))
    {:noreply, newState}
  end

  def handle_info(%HTTPoison.AsyncChunk{id: id, chunk: chunk}, %{url: url, content: content} = state) do
    # Logger.debug "DownloadWorker.handle_info: AsyncChunk(#{inspect id}, ...). State = {url: #{url},...}"
    newState = Map.put(state, :content, content <> chunk)

    {:noreply, newState}
  end

  def handle_info(%HTTPoison.AsyncEnd{id: id}, %{status: status, content: content, url: url, client: client, content_type: content_type} = state) do
    Logger.debug "#{inspect self()} DownloadWorker.handle_info: AsyncEnd(#{inspect id}). State: url: #{url}, client: #{inspect client}"

    send(client, {:page_ok, url, status, content_type, content})

    {:noreply, state}
  end

  def handle_info(%HTTPoison.Error{id: _id, reason: reason},  %{url: url, client: client} = state) do
    Logger.debug "#{inspect self()} HTTP error: #{reason}"
    {:noreply, state}
  end

  #
  # def handle_info(%HTTPoison.AsyncRedirect{id: id, to: redirect_url}, state) do
  #   Logger.debug "DownloadWorker.handle_info: AsyncRedirect(#{inspect id}, #{redirect_url}). State = ..."
  #   content = get_in(state, [:requests, id, :content])
  #   url = get_in(state, [:requests, id, :url])
  #   client = get_in(state, [:requests, id, :client])
  #
  #   Logger.debug("HTTP redirected from url: #{url} to #{redirect_url}")
  #
  #   send(client, {:page_redirect, url, redirect_url})
  #
  #   newState = pop_in(state, [:requests, id])
  #
  #   {:noreply, newState}
  # end

  def handle_info(request, state) do
    Logger.debug "#{inspect self()} Unknown message received: request=#{inspect request}, state=#{inspect state}"
  end

  defp make_headers(cookies) do
    [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:53.0) Gecko/20100101 Firefox/53.0"},
      {"Accept", "text/html"},
      {"Cookie", cookies}
    ]
  end

end
