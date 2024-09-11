defmodule TailwindConverter do
  alias TailwindConverter.{TailwindNodesManager, Utils, Mappings}

  @default_converter_config %{
    post_css_plugins: [],
    arbitrary_properties_is_enabled: false
  }

  @doc """
  Initialize the converter
  """
  def new(options \\ %{}) do
    tailwind_config = options[:tailwind_config] || %{content: []}
    resolved_tailwind_config = Utils.resolve_config(tailwind_config)

    config = Map.merge(@default_converter_config, options)
    |> Map.put(:tailwind_config, resolved_tailwind_config)
    |> Map.put(:mapping, Utils.converter_mapping_by_tailwind_theme(
      resolved_tailwind_config.theme,
      options[:rem_in_px]
    ))

    %__MODULE__{config: config}
  end

  def convert_css(%__MODULE__{} = converter, css) do
    nodes_manager = TailwindNodesManager.new()

    # Note: We'll need to implement a PostCSS-like processor in Elixir
    {:ok, parsed} = CSSParser.parse(css)

    converted_nodes = Enum.reduce(parsed.rules, nodes_manager, fn rule, acc ->
      case convert_rule(converter, rule) do
        nil -> acc
        converted -> TailwindNodesManager.merge_node(acc, converted)
      end
    end)

    nodes = TailwindNodesManager.get_nodes(converted_nodes)

    updated_nodes = Enum.map(nodes, fn node ->
      if length(node.tailwind_classes) > 0 do
        updated_rule = %{node.rule |
          children: [
            %AtRule{name: "apply", params: Enum.join(node.tailwind_classes, " ")}
            | node.rule.children
          ]
        }
        %{node | rule: updated_rule}
      else
        node
      end
    end)

    cleaned_root = clean_raws(parsed.root)

    %{nodes: updated_nodes, converted_root: cleaned_root}
  end

  defp convert_rule(%__MODULE__{} = converter, rule) do
    tailwind_classes = Enum.reduce(rule.declarations, [], fn declaration, acc ->
      case convert_declaration_to_classes(converter, declaration) do
        nil -> acc
        classes -> acc ++ classes
      end
    end)

    if length(tailwind_classes) > 0 do
      reduced_classes = Utils.reduce_tailwind_classes(tailwind_classes)

      prefixed_classes = if converter.config.tailwind_config.prefix do
        Enum.map(reduced_classes, fn class ->
          if String.starts_with?(class, "[") do
            class
          else
            converter.config.tailwind_config.prefix <> class
          end
        end)
      else
        reduced_classes
      end

      make_tailwind_node(converter, rule, prefixed_classes)
    else
      nil
    end
  end

  defp convert_declaration_to_classes(%__MODULE__{} = converter, declaration) do
    classes = case Mappings.declaration_converters_mapping()[declaration.prop] do
      nil -> []
      converter_fn -> converter_fn.(declaration, converter.config)
    end

    if length(classes) == 0 and converter.config.arbitrary_properties_is_enabled do
      ["[#{declaration.prop}:#{Utils.prepare_arbitrary_value(declaration.value)}]"]
    else
      classes
    end
  end

  defp make_tailwind_node(%__MODULE__{} = converter, rule, tailwind_classes) do
    {base_selector, class_prefix} = parse_selector(rule.selector)

    class_prefix_by_parent_nodes = convert_container_to_class_prefix(rule.parent)

    if class_prefix_by_parent_nodes do
      %{
        key: base_selector,
        root_rule_selector: base_selector,
        original_rule: rule,
        classes_prefix: class_prefix_by_parent_nodes <> class_prefix,
        tailwind_classes: tailwind_classes
      }
    else
      if class_prefix != "" do
        key = TailwindNodesManager.convert_rule_to_key(rule, base_selector)
        is_root_rule = key == base_selector

        %{
          key: key,
          root_rule_selector: if(is_root_rule, do: base_selector, else: nil),
          original_rule: rule,
          classes_prefix: class_prefix,
          tailwind_classes: tailwind_classes
        }
      else
        %{rule: rule, tailwind_classes: tailwind_classes}
      end
    end
  end

  defp parse_selector(raw_selector) do
    parsed_selectors = CSSWhat.parse(raw_selector)

    if length(parsed_selectors) != 1 do
      {raw_selector, ""}
    else
      parsed_selector = hd(parsed_selectors)
      {base_selectors, class_prefixes} = Enum.reduce(parsed_selector, {[], []}, fn selector_item, {base, prefixes} ->
        if Utils.is_traversal(selector_item) do
          {parsed_selector |> Enum.take(Enum.find_index(parsed_selector, &(&1 == selector_item)) + 1), []}
        else
          class_prefix = convert_selector_to_class_prefix(selector_item)
          if class_prefix, do: {base, [class_prefix | prefixes]}, else: {[selector_item | base], prefixes}
        end
      end)

      {
        CSSWhat.stringify([Enum.reverse(base_selectors)]),
        Enum.join(Enum.reverse(class_prefixes))
      }
    end
  end

  defp convert_selector_to_class_prefix(selector) do
    case selector do
      %{type: type} when type in [:pseudo, :"pseudo-element"] ->
        case Mappings.pseudos_mapping()[selector.name] do
          nil -> nil
          mapped -> "#{mapped}#{@config.tailwind_config.separator}"
        end

      %{type: :attribute, name: name} when binary_part(name, 0, 5) == "aria-" ->
        mapping_key = attribute_selector_to_mapping_key(selector, 6)
        case @config.mapping.aria[mapping_key] do
          nil -> nil
          mapped -> "#{mapped}#{@config.tailwind_config.separator}"
        end

      %{type: :attribute, name: name} when binary_part(name, 0, 5) == "data-" ->
        mapping_key = attribute_selector_to_mapping_key(selector, 6)
        case @config.mapping.data[mapping_key] do
          nil -> nil
          mapped -> "#{mapped}#{@config.tailwind_config.separator}"
        end

      _ -> nil
    end
  end

  defp attribute_selector_to_mapping_key(selector, from \\ 1) do
    stringified_selector = CSSWhat.stringify([[selector]])
    String.slice(stringified_selector, from..-2)
  end

  defp convert_container_to_class_prefix(container) do
    {media_params, supports_params} = collect_container_params(container)

    media_prefixes = if length(media_params) > 0 do
      convert_media_params_to_class_prefix(Enum.reverse(media_params))
    else
      ""
    end

    supports_prefixes = if length(supports_params) > 0 do
      convert_supports_params_to_class_prefix(Enum.reverse(supports_params))
    else
      ""
    end

    media_prefixes <> supports_prefixes
  end

  defp collect_container_params(container, media_params \\ [], supports_params \\ []) do
    if Utils.is_child_node(container) do
      if not Utils.is_at_rule_node(container) do
        {[], []}
      else
        case container.name do
          "media" -> collect_container_params(container.parent, [container.params | media_params], supports_params)
          "supports" -> collect_container_params(container.parent, media_params, [container.params | supports_params])
          _ -> {[], []}
        end
      end
    else
      {media_params, supports_params}
    end
  end
end
