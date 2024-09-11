defmodule TailwindConverter.Utils.NormalizeNumbersInString do
  @moduledoc """
  Utility module for normalizing numbers in a string by adding a leading zero to decimal numbers.
  """

  @spec normalize_numbers_in_string(String.t()) :: String.t()
  def normalize_numbers_in_string(string) when is_binary(string) do
    Regex.replace(~r/(^|[,;+\-\/*\s])(\.\d+)/, string, "\\10\\2")
  end

  def normalize_numbers_in_string(non_string), do: to_string(non_string)
end
