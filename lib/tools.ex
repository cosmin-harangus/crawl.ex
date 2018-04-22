defmodule Tools do
  @wikipedia_base_url "https://en.wikipedia.org/wiki"

  def make_wiki_url(page), do: @wikipedia_base_url <> "/" <> page
  
  def is_wiki_url?(url), do: String.starts_with?(url, @wikipedia_base_url)

  def render_path(path), do: "[" <> Enum.join(path, " ~> ") <> "]"

  def extract_urls(html) do
    Floki.find(html, "a")
    |> Enum.map(fn [{"a", [{"href", url}]}] -> url end)
    |> Enum.filter(&is_wiki_url?/1)
  end
end
