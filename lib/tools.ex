defmodule Tools do
  def render_results(results) do
    Map.to_list(results)
    |> Enum.sort_by(fn {url, _path} -> url end)
    |> Enum.sort_by(fn {_url, path} -> Enum.count(path) end)
    |> Enum.map(fn {url, path} -> "  #{url} ----------------> #{Tools.render_path(path ++ [url])}" end)
  end

  def render_path(path) do
    path_as_str =
      path
      |> Enum.reverse()
      |> Enum.join(" ~> ")

     "[#{path_as_str}]"
  end

  def content_type(headers) do
      case Enum.find(headers, fn {k, _v} -> String.downcase(k) == "content-type" end) do
        nil -> "text/html"
        {_k, v} -> v
      end
  end

  def extract_urls(html) do
    html
    |> Floki.find("a")
    |> Floki.attribute("href")
    |> Enum.filter(fn x -> String.starts_with?(x, "http://") or String.starts_with?(x, "https://") end)
    |> Enum.map(fn x -> x |> String.split("#", parts: 2) |> Enum.at(0) end)
  end

  def extract_cookies(headers) do
    Enum.reduce(headers, %{}, fn {key, value}, cookies ->
      case String.downcase(key) do
        "set-cookie" ->
          [key_value_string | _rest] = String.split(value, "; ")
          [key, value] = String.split(key_value_string, "=", parts: 2)
          Map.put(cookies, key, value)

        _ ->
          cookies
      end
    end)
  end

  def empty_map?(m), do: Map.keys(m) |> Enum.empty?()
end
