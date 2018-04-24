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

  def main() do
    main(System.argv())
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

    DownloadServer.get(start_url)

    end_url = Tools.make_wiki_url(end_page)

    %{
      :in_progress =>%{start_url => [start_url]},
      :downloaded => MapSet.new
    }
    |> wait_for_response(end_url, @max_retries)
  end

  defp wait_for_response(args, end_url, retries) do
    receive do
      {:page_ok, ^end_url, _} ->
        handle_end_page(args, end_url)

      {:page_ok, url, content} ->
        handle_page_ok(args, url, content)
        |> wait_for_response(end_url, @max_retries)

      {:page_error, url, reason} ->
        handle_page_error(args, url, reason)
        |> wait_for_response(end_url, @max_retries)

      # {:page_redirect, current_url, redirect_url} ->
      #   current_path = requested[current_url]
      #
      #   Logger.info "Visiting page #{current_url}. Redirected to #{redirect_url}. Current path: #{Tools.render_path(current_path)}"

      other -> Logger.warn "Other message received: #{other}"
    after
      1_000 ->
        if retries > 0 do
          handle_retry(args, retries)
          |> wait_for_response(end_url, retries - 1)
        else
          handle_giveup(args)
        end
    end
  end

  defp handle_giveup(%{in_progress: in_progress, downloaded: downloaded} = args) do
    Logger.info "*** Timeout expired.\n*** Downloads in progress: #{inspect in_progress}\n*** Downloaded: #{inspect downloaded}\n*** Exit. "
  end

  defp handle_retry(%{in_progress: in_progress, downloaded: downloaded} = args, retries_left) do
    Logger.info "Still waiting: no results received yet.\n*** Downloads in progress: #{map_size(in_progress)}\n*** Downloaded: #{map_size(downloaded)}. Retries left: #{retries_left}"
    args
  end

  defp handle_page_error(args, url, reason) do
      Logger.warn "Error while requested page #{url}. Reason: #{reason}"
      args
  end

  defp handle_end_page(%{in_progress: in_progress}, url) do
    path = in_progress[url]
    Logger.info "*****************************************************************************************************"
    Logger.info "*** End page #{url} reached with path: #{Tools.render_path(path)}"
    Logger.info "*****************************************************************************************************"
  end

  defp handle_page_ok(%{in_progress: in_progress, downloaded: downloaded} = args, current_url, content) do
    current_path = in_progress[current_url]

    Logger.info "Page downloaded #{current_url}. Current path: #{Tools.render_path(current_path)}"

    urls =
      Tools.extract_urls(content)
      # |> Enum.take_random(1) # !!!!!!!!!!! FIXME

    Logger.info "Urls found in page: [#{Enum.join(urls, "\n")}]"


    newInProgress =
      urls
      |> Enum.reduce(%{},fn (url, acc) -> Map.put(acc, url, [url | current_path]) end)

    urls
    |> Enum.each(&DownloadServer.get/1)

    %{
      :downloaded =>
        downloaded
        |> MapSet.put(current_url),

      :in_progress =>
        in_progress
        |> Map.delete(current_url)
        |> Map.merge(newInProgress)
    }
  end
end
