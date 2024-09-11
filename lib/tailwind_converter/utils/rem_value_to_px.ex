defmodule TailwindConverter.Utils.RemValueToPx do
  @rem_value_regexp ~r/^(\d+)?\.?\d+rem$/

  def convert(value, rem_in_px) when is_binary(value) and is_number(rem_in_px) do
    trimmed_value = String.trim(value)
    if Regex.match?(@rem_value_regexp, trimmed_value) do
      case Float.parse(trimmed_value) do
        {number, _} -> "#{number * rem_in_px}px"
        :error -> value
      end
    else
      value
    end
  end
end
