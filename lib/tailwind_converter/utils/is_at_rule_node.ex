defmodule TailwindConverter.Utils.IsAtRuleNode do
  @moduledoc """
  Utility module for checking if a node is an AtRule node in the CSS AST.
  """

  alias TailwindConverter.AST.{Node, AtRule}

  @spec is_at_rule_node(Node.t() | nil) :: boolean()
  def is_at_rule_node(nil), do: false
  def is_at_rule_node(%AtRule{}), do: true
  def is_at_rule_node(%Node{type: :atrule}), do: true
  def is_at_rule_node(_), do: false
end
