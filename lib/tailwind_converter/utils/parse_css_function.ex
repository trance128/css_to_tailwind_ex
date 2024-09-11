defmodule TailwindConverter.Utils.ParseCSSFunction do
  @moduledoc """
  Utility module for parsing a single CSS function.
  """

  @css_function_regex ~r/(?<name>[\w-]+)\((?<value>.*?)\)/

  @spec parse_css_function(String.t()) :: %{name: String.t() | nil, value: String.t() | nil}
  def parse_css_function(string) when is_binary(string) do
    case Regex.named_captures(@css_function_regex, string) do
      %{"name" => name, "value" => value} -> %{name: name, value: value}
      _ -> %{name: nil, value: nil}
    end
  end

  def parse_css_function(_), do: %{name: nil, value: nil}
end
