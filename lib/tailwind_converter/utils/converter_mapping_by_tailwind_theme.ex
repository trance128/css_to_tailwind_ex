defmodule TailwindConverter.Utils.ConverterMappingByTailwindTheme do
  @color_keys ["fill", "stroke"]
  @size_keys [
    "backdropBlur", "backgroundSize", "blur", "borderRadius", "borderSpacing",
    "borderWidth", "columns", "divideWidth", "flexBasis", "gap", "height",
    "inset", "letterSpacing", "lineHeight", "margin", "maxHeight", "maxWidth",
    "minHeight", "minWidth", "outlineOffset", "outlineWidth", "padding",
    "ringOffsetWidth", "ringWidth", "scrollMargin", "scrollPadding", "space",
    "spacing", "strokeWidth", "textDecorationThickness", "textUnderlineOffset",
    "translate", "width"
  ]

  def normalize_value(value) when is_binary(value) do
    value
    |> normalize_numbers_in_string()
    |> remove_unnecessary_spaces()
  end

  def normalize_color_value(color_value) when is_binary(color_value) do
    case Colord.parse(color_value) do
      {:ok, color} -> Colord.to_hex(color)
      _ -> color_value
    end
  end

  def normalize_zero_size_value(value) when is_binary(value) do
    if String.trim(value) == "0px", do: "0", else: value
  end

  def normalize_size_value(size_value, rem_in_px \\ nil) when is_binary(size_value) do
    size_value
    |> (if rem_in_px, do: &rem_value_to_px(&1, rem_in_px), else: &(&1))
    |> normalize_numbers_in_string()
    |> normalize_zero_size_value()
  end

  def normalize_at_rule_params(at_rule_param) when is_binary(at_rule_param) do
    at_rule_param
    |> String.replace(~r/\(|\)/, "")
    |> remove_unnecessary_spaces()
  end

  defp map_theme_tokens(tokens, value_converter_fn) when is_map(tokens) do
    tokens
    |> Enum.map(fn {token_key, token_value} ->
      case value_converter_fn.(token_value, token_key) do
        nil -> nil
        converted_value -> {converted_value, token_key}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp is_color_key(key) when is_binary(key) do
    key in @color_keys or String.contains?(String.downcase(key), "color")
  end

  defp is_size_key(key) when is_binary(key), do: key in @size_keys

  defp convert_font_sizes(font_sizes, rem_in_px \\ nil) do
    map_theme_tokens(font_sizes, fn font_size_value, _token_key ->
      case font_size_value do
        nil -> nil
        value when is_binary(value) -> normalize_size_value(value, rem_in_px)
        [value | _] when is_binary(value) -> normalize_size_value(value, rem_in_px)
        _ -> nil
      end
    end)
  end

  defp convert_screens(screens) when is_list(screens), do: %{}
  defp convert_screens(screens) when is_map(screens) do
    map_theme_tokens(screens, fn screen_value, _token_key ->
      if screen_value do
        screen_value
        |> build_media_query_by_screen()
        |> normalize_at_rule_params()
      else
        nil
      end
    end)
  end

  defp convert_colors(colors) when is_map(colors) do
    colors
    |> flatten_object()
    |> map_theme_tokens(fn color_value, _token_key ->
      color_value
      |> to_string()
      |> normalize_color_value()
    end)
  end

  defp convert_sizes(sizes, rem_in_px) when is_map(sizes) do
    map_theme_tokens(sizes, fn size_value, _token_key ->
      size_value
      |> to_string()
      |> normalize_size_value(rem_in_px)
    end)
  end

  defp convert_other_theme_tokens(nil), do: nil
  defp convert_other_theme_tokens(tokens) when is_map(tokens) do
    map_theme_tokens(tokens, fn token_value, _token_key ->
      token_value
      |> to_string()
      |> normalize_value()
    end)
  end

  def converter_mapping_by_tailwind_theme(resolved_tailwind_theme, rem_in_px \\ nil) do
    resolved_tailwind_theme
    |> Enum.reject(fn {key, _} -> key in ["keyframes", "container", "fontFamily"] end)
    |> Enum.reduce(%{}, fn {key, theme_item}, acc ->
      converted_value = cond do
        key == "fontSize" -> convert_font_sizes(theme_item, rem_in_px)
        key == "screens" -> convert_screens(theme_item)
        is_color_key(key) -> convert_colors(theme_item)
        is_size_key(key) -> convert_sizes(theme_item, rem_in_px)
        true -> convert_other_theme_tokens(theme_item)
      end
      Map.put(acc, key, converted_value)
    end)
  end
end
