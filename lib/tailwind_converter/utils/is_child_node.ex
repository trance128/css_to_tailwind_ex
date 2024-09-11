defmodule TailwindConverter.Utils.IsChildNode do
  @moduledoc """
  Utility module for checking if a node is a child node in the CSS AST.
  """

  alias TailwindConverter.AST.Node

  @spec is_child_node(Node.t() | nil) :: boolean()
  def is_child_node(nil), do: false
  def is_child_node(%Node{type: type}) when type in [:atrule, :rule, :decl, :comment], do: true
  def is_child_node(_), do: false
end
