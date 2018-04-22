defmodule CrawlerApp do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.debug "Application starting..."
    DownloadServer.start_link()
  end

end
