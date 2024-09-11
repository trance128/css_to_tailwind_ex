defmodule TailwindConverter.Utils.DetectIndent do
  @moduledoc """
  Utility module for detecting indentation in CSS AST.
  """

  alias TailwindConverter.AST.{Container, Node}

  @spec detect_indent(Container.t()) :: String.t()
  def detect_indent(%Container{raws: %{indent: indent}} = _root) when is_binary(indent), do: indent
  def detect_indent(root) do
    detect_indent_recursive(root, "    ")
  end

  defp detect_indent_recursive(root, default_indent) do
    result = Enum.reduce_while(Node.walk(root), default_indent, fn node, acc ->
      with %Node{parent: p} <- node,
           true <- p && p != root && p.parent && p.parent == root,
           %{raws: %{before: before}} <- node,
           true <- is_binary(before) do
        parts = String.split(before, "\n")
        detected = String.replace(List.last(parts), ~r/\S/, "")
        {:halt, detected}
      else
        _ -> {:cont, acc}
      end
    end)

    if result == "", do: default_indent, else: result
  end
end
