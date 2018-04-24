defmodule Tools do
  @wikipedia "https://en.wikipedia.org"
  @wiki_path "#{@wikipedia}/wiki"

  def make_wiki_url(s), do: @wiki_path <> "/" <> s

  def is_wiki_url?(url), do: String.starts_with?(url, @wikipedia) or not(String.starts_with?(url, "http"))

  def render_path(path) do
    path_as_str =
      path
      |> Enum.reverse()
      |> Enum.join(" ~> ")

     "[#{path_as_str}]"
  end

  def extract_urls(html) do
    html
    |> Floki.find("a")
    |> Floki.attribute("href")
    # |> Enum.filter(fn x -> String.starts_with?(x, "http://") or String.starts_with?(x, "https://") end)
    |> Enum.filter(fn x -> String.starts_with?(x, "/wiki") end)
    |> Enum.map(fn x -> @wikipedia <> "/" <> x end)
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
end
