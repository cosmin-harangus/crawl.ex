defmodule State do
  def check_termination(%{in_progress: in_progress, results: results} = state) do
    if Tools.empty_map?(in_progress) do
      {:done, results}
    else
      {:processing, state}
    end
  end

  def add_in_progress(%{in_progress: in_progress} = state, jobs) do
    in_progress = Map.merge(in_progress, jobs)

    state
    |> Map.put(:in_progress, in_progress)
  end

  def get_in_progress(state), do: state[:in_progress]

  def get_in_progress(%{in_progress: in_progress}, url), do: in_progress[url]

  def remove_in_progress(%{in_progress: in_progress} = state, url) do
    state
    |> Map.put( :in_progress, Map.delete(in_progress, url))
  end

  def add_result(%{in_progress: in_progress, results: results} = state, url, result), do:
    state
    |> Map.put(:results, Map.put(results, url, result))

  def contains(%{in_progress: in_progress, results: results}, url), do:
    Map.has_key?(results, url) or Map.has_key?(in_progress, url)

end
