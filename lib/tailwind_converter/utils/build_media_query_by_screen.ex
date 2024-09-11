defmodule TailwindConverter.Utils.BuildMediaQueryByScreen do
  @type screen :: String.t() | screen_map() | [screen_map()]
  @type screen_map :: %{
    optional(:raw) => String.t(),
    optional(:min) => String.t(),
    optional(:max) => String.t()
  }

  @spec build_media_query_by_screen(screen()) :: String.t()
  def build_media_query_by_screen(screens) when is_binary(screens) do
    "(min-width: #{screens})"
  end

  def build_media_query_by_screen(screens) when is_map(screens) do
    build_media_query_by_screen([screens])
  end

  def build_media_query_by_screen(screens) when is_list(screens) do
    screens
    |> Enum.map(&build_single_screen_query/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp build_single_screen_query(%{raw: raw}) when is_binary(raw) do
    raw
  end

  defp build_single_screen_query(screen) do
    conditions = []

    conditions = if Map.has_key?(screen, :min) do
      ["(min-width: #{screen.min})" | conditions]
    else
      conditions
    end

    conditions = if Map.has_key?(screen, :max) do
      ["(max-width: #{screen.max})" | conditions]
    else
      conditions
    end

    case conditions do
      [] -> nil
      _ -> Enum.join(conditions, " and ")
    end
  end
end
