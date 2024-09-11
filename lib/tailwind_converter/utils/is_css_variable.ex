defmodule TailwindConverter.Utils.IsCSSVariable do
  @moduledoc """
  Utility module for checking if a value is a CSS variable.
  """

  @spec is_css_variable(String.t()) :: boolean()
  def is_css_variable(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.match?(~r/^var\((--.+?)\)$/)
  end

  def is_css_variable(_), do: false
end
