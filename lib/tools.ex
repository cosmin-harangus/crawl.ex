defmodule Tools do
  @wikipedia "https://en.wikipedia.org"
  @wiki_path "#{@wikipedia}/wiki"

  def make_wiki_url(s), do: @wiki_path <> "/" <> s

  def is_wiki_url?(url), do: String.starts_with?(url, @wikipedia) or not(String.starts_with?(url, "http"))

  def render_path(path), do: "[" <> Enum.join(path, " ~> ") <> "]"

  def extract_urls(html) do
    html
    |> Floki.find("a")
    |> Floki.attribute("href")
    |> Enum.filter(fn x -> String.starts_with?(x, "/wiki") end)
    |> Enum.map(fn x -> @wikipedia <> "/" <> x end)
  end
end
