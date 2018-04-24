defmodule CrawlerApp do
  use Application
  require Logger

  def start(_type, _args) do
    {:ok, cookie_jar} = CookieJar.new()
    Logger.debug "Cookie jar #{inspect cookie_jar} initialized."

    {:ok, download_server} = DownloadServer.start_link(cookie_jar)

    Logger.debug "Application started: cookie_jar=#{inspect cookie_jar}, download_server=#{inspect download_server}"

    {:ok, download_server}
  end

end
