defmodule TailwindConverter.Utils.RemoveUnnecessarySpaces do
  def remove(string) when is_binary(string) do
    Regex.replace(~r/(\s+)?([,;:])(\s+)?/u, string, "\\2")
  end
end
