defmodule CrawlerMain do
  require Logger
  require DownloadServer
  require Tools

  @timeout 1_000

  def test do
    main(["3","20","https://hexdocs.pm/"])
  end

  def main do
    main(System.argv())
  end

  def main(args) do
    args
    |> parse_args
    |> process
  end

  defp parse_args(args) do
    case OptionParser.parse(args) do
      { _, [depth, fork_factor, start_url], _ } -> {:ok, elem(Integer.parse(depth),0), elem(Integer.parse(fork_factor), 0), start_url}
      { _, _, _ } -> {:help}
    end
  end

  defp process({:help}) do
    IO.puts "Usage: ./grepex depth fork-factor start-url"
    IO.puts "Runs a breadth-first-search starting for the <word> from the <start-url> up to a given <depth>."
    IO.puts "For each page a maximum <fork-factor> links per page are followed"
    IO.puts "The sequence of links followed is printed for each downloaded page"
    IO.puts "Example ./crawler 3 2 http://www.bbc.com/news"
  end

  defp process({:ok, max_depth, fork_factor, start_url}) do
    Logger.info "[#{inspect self()}] Starting crawling with depth=#{inspect max_depth}, fork_factor=#{inspect fork_factor}, start_url=#{start_url}"

    {:ok, downloader} = Downloader.start_link()
    {:ok, parser} = Parser.start_link(fork_factor)
    {:ok, feeder} = Feeder.start_link(max_depth)
    {:ok, display} = Display.start_link()
    # {:ok, ticker} = Ticker.start_link(@timeout)

    GenStage.sync_subscribe(parser, to: downloader)
    GenStage.sync_subscribe(feeder, to: parser)
    GenStage.sync_subscribe(downloader, to: feeder)
    GenStage.sync_subscribe(display, to: feeder)
    # GenStage.sync_subscribe(ticker, to: feeder)


    Downloader.download(downloader, start_url)

    Process.sleep(10_000)

    GenStage.stop(feeder)
    # [downloader, parser, feeder, display]
    # |> Enum.each(&GenStage.stop/1)

    IO.puts "*** Exit. "
  end
end
