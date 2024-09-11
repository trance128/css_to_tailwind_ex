defmodule TailwindConverter.Utils.FlattenObject do
  @moduledoc """
  Utility module for flattening nested objects (maps) in Elixir.
  """

  @type key :: String.t() | atom() | number()

  @spec flatten_object(map(), String.t()) :: map()
  def flatten_object(object, separator \\ "-")

  def flatten_object(object, separator) when is_map(object) do
    do_flatten_object(object, separator, [])
  end

  def flatten_object(non_object, _separator), do: %{} = non_object

  defp do_flatten_object(object, separator, prefix) do
    Enum.reduce(object, %{}, fn {key, value}, acc ->
      key_string = to_string(key)
      new_prefix = prefix ++ [key_string]

      if is_map(value) and not Map.empty?(value) do
        nested_flat = do_flatten_object(value, separator, new_prefix)
        Map.merge(acc, nested_flat)
      else
        flat_key = Enum.join(new_prefix, separator)
        Map.put(acc, flat_key, value)
      end
    end)
  end
end
