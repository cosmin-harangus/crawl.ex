defmodule CrawlerApp do
  use Application

  def start(_type, _args) do
    DownloadServer.start_link()
  end

end
