defmodule TailwindConverter.Utils.ParseCSSFunctions do
  @moduledoc """
  Utility module for parsing multiple CSS functions in a string.
  """

  alias TailwindConverter.Utils.ParseCSSFunction

  @css_functions_regex ~r/(?<name>[\w-]+)\((?<value>.*?)\)/

  @spec parse_css_functions(String.t()) :: [%{name: String.t() | nil, value: String.t() | nil}]
  def parse_css_functions(value) when is_binary(value) do
    value
    |> String.trim()
    |> then(&Regex.scan(@css_functions_regex, &1))
    |> Enum.map(fn [full_match | _] -> ParseCSSFunction.parse_css_function(full_match) end)
  end

  def parse_css_functions(_), do: []
end
