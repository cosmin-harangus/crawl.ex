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
    download(start_url)

    config = %{:max_depth => max_depth, :fork_factor => fork_factor}
    initial_state = %{ :in_progress =>%{start_url => [start_url]}, :results => %{} }

    wait_for_response(config, initial_state)

    IO.puts "*** Exit. "
  end

  defp wait_for_response(config, state) do
    receive do
      {:page_ok, url, response} ->
        handle_page_ok(config, state, url, response)
        |> check_stop_condition(config)

      {:page_error, url, reason} ->
        handle_page_error(state, url, reason)
        |> check_stop_condition(config)
    after
      @timeout ->
        IO.puts "Timeout."
        IO.puts "*** Downloads in progress: #{inspect State.get_in_progress(state)}"
    end
  end

  defp check_stop_condition({:processing, new_state}, config), do: wait_for_response(config, new_state)
  defp check_stop_condition({:done, results}, _) do
    IO.puts "*** All downloads are finished."
    print_results(results)
  end

  defp print_results(results) do
    IO.puts "*** results:"

    Tools.render_results(results)
    |> Enum.each(&IO.puts/1)
  end

  defp handle_page_error(state, url, reason) do
      Logger.warn "[#{inspect self()}] Error while requested page #{url}. Reason: #{inspect reason}"

      state
      |> State.remove_in_progress(url)
      |> State.get_results()
  end

  defp handle_page_ok(config, state, current_url, response) do
    Logger.info "[#{inspect self()}] #{current_url} Enter handle_page_ok."
    Logger.debug "[#{inspect self()}] #{current_url} handle_page_ok: args=#{inspect state}"

    page_urls = extract_urls(response, config[:fork_factor])

    Logger.debug "[#{inspect self()}] #{current_url} handle_page_ok: urls=#{inspect page_urls}"

    current_path = State.get_in_progress(state, current_url)

    jobs = compute_jobs(state, current_path, page_urls, config[:max_depth])

    Map.keys(jobs)
    |> Enum.each(&download/1)

    state
    |> State.add_result(current_url)
    |> State.remove_in_progress(current_url)
    |> State.add_in_progress(jobs)
    |> State.get_results()
  end

  def extract_urls(%{content_type: content_type, content: content}, fork_factor) do
    if String.starts_with?(content_type, "text/html") do
      Tools.extract_urls(content)
      |> Enum.take_random(fork_factor)
    else
      []
    end
    |> MapSet.new
  end

  def compute_jobs(state, current_path, urls, max_depth) do
    if Enum.count(current_path) < max_depth do
      urls
      |> Enum.filter(fn u -> not(State.contains(state, u)) end)
      |> Enum.reduce(%{},fn (url, acc) -> Map.put(acc, url, [url | current_path]) end)
    else
      %{}
    end
  end

  defp download(url) do
    Logger.debug "[#{inspect self()}] download url=#{url}"
    # DownloadServer.get(url, self())
    node =
      [Node.self() | Node.list()]
      |> Enum.take_random(1)
      |> Enum.at(0)

    :rpc.call(:"#{node}", DownloadServer, :get, [url, self()])
  end
end
