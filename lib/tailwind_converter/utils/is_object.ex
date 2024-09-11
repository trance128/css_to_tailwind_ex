defmodule TailwindConverter.Utils.IsObject do
  @moduledoc """
  Utility module for checking if a value is a map (object in JavaScript terms).
  """

  @spec is_object(any()) :: boolean()
  def is_object(value) when is_map(value), do: true
  def is_object(_), do: false
end
