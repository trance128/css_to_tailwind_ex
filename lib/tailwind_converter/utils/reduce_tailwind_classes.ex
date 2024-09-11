defmodule TailwindConverter.Utils.TailwindClassesReductionManager do
  defstruct resolved_classes: [], map: %{
    m: %{mx: %{ml: [], mr: []}, my: %{mt: [], mb: []}},
    p: %{px: %{pl: [], pr: []}, py: %{pt: [], pb: []}},
    "scroll-m": %{
      "scroll-mx": %{"scroll-ml": [], "scroll-mr": []},
      "scroll-my": %{"scroll-mt": [], "scroll-mb": []}
    },
    "scroll-p": %{
      "scroll-px": %{"scroll-pl": [], "scroll-pr": []},
      "scroll-py": %{"scroll-pt": [], "scroll-pb": []}
    },
    rounded: %{
      "rounded-t": %{"rounded-tl": [], "rounded-tr": []},
      "rounded-r": %{"rounded-tr": [], "rounded-br": []},
      "rounded-b": %{"rounded-bl": [], "rounded-br": []},
      "rounded-l": %{"rounded-tl": [], "rounded-bl": []}
    },
    border: %{
      "border-x": %{"border-l": [], "border-r": []},
      "border-y": %{"border-t": [], "border-b": []}
    },
    scale: %{"scale-x": [], "scale-y": []},
    inset: %{
      "inset-x": %{left: [], right: []},
      "inset-y": %{top: [], bottom: []}
    }
  }

  def new do
    %__MODULE__{}
  end

  def append_class_name(%__MODULE__{} = manager, class_name) do
    {value, class_prefix} = parse_tailwind_class(class_name)

    if is_nil(value) or not recursive_set_value(class_prefix, value, manager.map) do
      %{manager | resolved_classes: [class_name | manager.resolved_classes]}
    else
      manager
    end
  end

  def reduce(%__MODULE__{} = manager) do
    reduced_classes =
      Enum.reduce(Map.keys(manager.map), manager.resolved_classes, fn map_key, acc ->
        resolved = recursive_resolve_classes(Map.get(manager.map, map_key), [])
        Enum.reduce(resolved, acc, fn {value, _}, classes ->
          [to_tailwind_class(map_key, value) | classes]
        end)
      end)

    %{manager | resolved_classes: reduced_classes}
  end

  defp recursive_set_value(key, value, target_object) do
    Enum.reduce_while(target_object, false, fn {object_key, object_value}, acc ->
      cond do
        object_key == key and is_map(object_value) ->
          recursive_set_value_to_all_keys(value, object_value)
          {:halt, true}
        object_key == key and is_list(object_value) ->
          {:halt, true}
        is_map(object_value) ->
          case recursive_set_value(key, value, object_value) do
            true -> {:halt, true}
            false -> {:cont, acc}
          end
        true ->
          {:cont, acc}
      end
    end)
  end

  defp recursive_set_value_to_all_keys(value, target_object) do
    Enum.each(Map.keys(target_object), fn key ->
      recursive_set_value(key, value, target_object)
    end)
  end

  defp recursive_resolve_classes(target_object, resolved_classes) do
    Enum.reduce(Map.keys(target_object), %{}, fn current_class_prefix, common_values_map ->
      object_value = Map.get(target_object, current_class_prefix)

      new_common_values =
        cond do
          is_map(object_value) ->
            recursive_resolve_classes(object_value, resolved_classes)
            |> Enum.map(fn {value, _} -> {value, current_class_prefix} end)
            |> Enum.into(%{})
          is_list(object_value) ->
            Enum.map(object_value, fn value -> {value, current_class_prefix} end)
            |> Enum.into(%{})
        end

      Map.merge(common_values_map, new_common_values, fn _k, v1, v2 ->
        if v1 == v2, do: v1, else: nil
      end)
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})
    end)
  end

  defp to_tailwind_class(class_prefix, value) do
    value = to_string(value)

    if String.starts_with?(value, "-") do
      "-#{class_prefix}-#{String.slice(value, 1..-1//-1)}"
    else
      "#{class_prefix}-#{value}"
    end
  end

  defp parse_tailwind_class(tailwind_class) do
    {is_negative, tailwind_class} =
      if String.starts_with?(tailwind_class, "-") do
        {true, String.slice(tailwind_class, 1..-1//-1)}
      else
        {false, tailwind_class}
      end

    case String.split(tailwind_class, "-", parts: 2) do
      [class_prefix] ->
        {nil, class_prefix}
      [class_prefix, value] ->
        value = if is_negative, do: "-#{value}", else: value
        {value, class_prefix}
    end
  end
end

defmodule TailwindConverter.Utils.ReduceTailwindClasses do
  alias TailwindConverter.Utils.TailwindClassesReductionManager

  def reduce_tailwind_classes(tailwind_classes) do
    manager = TailwindClassesReductionManager.new()

    tailwind_classes
    |> Enum.reduce(manager, fn class_name, acc ->
      TailwindClassesReductionManager.append_class_name(acc, class_name)
    end)
    |> TailwindClassesReductionManager.reduce()
    |> Map.get(:resolved_classes)
  end
end
