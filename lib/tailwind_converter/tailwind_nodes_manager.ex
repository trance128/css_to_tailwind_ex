defmodule TailwindConverter.TailwindNodesManager do
  alias TailwindConverter.Utils

  defmodule ResolvedTailwindNode do
    defstruct [:rule, :tailwind_classes]
  end

  defmodule UnresolvedTailwindNode do
    defstruct [:key, :root_rule_selector, :original_rule, :classes_prefix, :tailwind_classes]
  end

  @type tailwind_node :: ResolvedTailwindNode.t() | UnresolvedTailwindNode.t()

  defstruct nodes_map: %{}

  def new(initial_nodes \\ []) do
    manager = %__MODULE__{}
    Enum.reduce(initial_nodes, manager, fn node, acc ->
      merge_node(acc, node)
    end)
  end

  def merge_node(manager, node) do
    node_is_resolved = is_struct(node, ResolvedTailwindNode)
    node_key = if node_is_resolved do
      convert_rule_to_key(node.rule)
    else
      node.key
    end

    case Map.get(manager.nodes_map, node_key) do
      nil ->
        if node_is_resolved do
          put_in(manager.nodes_map[node_key], node)
        else
          rule = if node.root_rule_selector do
            new_rule = %Rule{selector: node.root_rule_selector}
            root_child = up_to_root_child(node.original_rule)
            if root_child do
              Utils.insert_before(node.original_rule.root(), root_child, new_rule)
            end
            new_rule
          else
            node.original_rule
          end

          resolved_node = %ResolvedTailwindNode{
            rule: rule,
            tailwind_classes: Enum.map(node.tailwind_classes, &("#{node.classes_prefix}#{&1}"))
          }
          put_in(manager.nodes_map[node_key], resolved_node)
        end

      found_node ->
        updated_classes = found_node.tailwind_classes ++ if node_is_resolved do
          node.tailwind_classes
        else
          Enum.map(node.tailwind_classes, &("#{node.classes_prefix}#{&1}"))
        end
        put_in(manager.nodes_map[node_key].tailwind_classes, updated_classes)
    end
  end

  def merge_nodes(manager, nodes) do
    Enum.reduce(nodes, manager, fn node, acc ->
      merge_node(acc, node)
    end)
  end

  def has_node?(manager, key), do: Map.has_key?(manager.nodes_map, key)

  def get_node(manager, key), do: Map.get(manager.nodes_map, key)

  def get_nodes(manager), do: Map.values(manager.nodes_map)

  defp up_to_root_child(node) do
    Stream.iterate(node, & &1.parent)
    |> Stream.take_while(&(&1.parent && &1.parent.type != :root && Utils.is_child_node?(&1.parent)))
    |> Enum.at(-1)
  end

  def convert_rule_to_key(rule, overridden_selector \\ nil) do
    parent_key = Stream.iterate(rule.parent, & &1.parent)
    |> Stream.take_while(&Utils.is_child_node?/1)
    |> Enum.map_join("__", fn
      %{__struct__: AtRule} = at_rule -> make_single_at_rule_key(at_rule)
      %{__struct__: Rule} = rule -> make_single_rule_key(rule)
    end)

    parent_key <> (overridden_selector || rule.selector)
  end

  defp make_single_at_rule_key(at_rule), do: "a(#{at_rule.name}|#{at_rule.params})"

  defp make_single_rule_key(rule), do: "r(#{rule.selector})"
end
