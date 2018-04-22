defmodule CrawlerMain do
  require Logger
  require DownloadServer
  require Tools

  @max_retries 3

  def main(args) do
    args
    |> parse_args
    |> process
  end

  defp parse_args(args) do
    case OptionParser.parse(args) do
      { _, [start_page, end_page], _ } -> {:ok, start_page, end_page}
      { _, _, _ } -> {:help}
    end
  end

  defp process(:help) do
    IO.puts "Usage: ./grepex start_page end_page"
    IO.puts "Runs a breadth-first-search in Wikipedia in order to find the shortest path from start_page to end_page"
    IO.puts "Example ./grepex Main_Page Aristotle"
  end

  defp process({:ok, start_page, end_page}) do
    start_url = Tools.make_wiki_url(start_page)

    Logger.info "TADAAAA"
    DownloadServer.get(start_url)

    end_url = Tools.make_wiki_url(end_page)

    wait_for_response(%{start_url => [start_url]}, end_url, @max_retries)
  end

  defp wait_for_response(requested, end_url, retries) do
    receive do
      {:page_ok, ^end_url, _} ->
        path = requested[end_url]
        Logger.info "*****************************************************************************************************"
        Logger.info "*** End page #{end_url} reached with path: #{Tools.render_path(path)}"
        Logger.info "*****************************************************************************************************"

      {:page_ok, current_url, content} ->
        current_path = requested[current_url]

        Logger.info "Visiting page #{current_url}. Current path: #{Tools.render_path(current_path)}"

        urls = Tools.extract_urls(content)

        urls
        |> Enum.each(&DownloadServer.get/1)

        urls
        |> Enum.reduce(requested, fn (url, acc) -> Map.put(acc, url, [url | current_path]) end)
        |> wait_for_response(end_url, @max_retries)

      {:page_error, url, reason} ->
        Logger.warn "Error while requested page #{url}. Reason: #{reason}"

        requested
        |> wait_for_response(end_url, @max_retries)
    after
      1_000 ->
        in_progress = map_size(requested)
        if retries > 0 do
          Logger.info "Still waiting: no results received yet. Downloads in progress: #{in_progress}. Retries left: #{retries}"
          wait_for_response(requested, end_url, retries - 1)
        else
          Logger.info "Timeout expired. Downloads in progress: #{in_progress}. Exit. "
        end
    end
  end

end
