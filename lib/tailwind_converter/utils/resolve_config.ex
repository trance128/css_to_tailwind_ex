defmodule TailwindConverter.Utils.ResolveConfig do
  @type core_plugin_list :: [atom()]

  @type config :: %{
    prefix: String.t(),
    separator: String.t(),
    core_plugins: [String.t()],
    theme: map(),
    # Add other config fields as needed
  }

  @type resolved_config :: %{
    prefix: String.t(),
    separator: String.t(),
    core_plugins: %{atom() => boolean()},
    theme: map(),
    # Add other resolved config fields as needed
  }

  @spec resolve(config()) :: resolved_config()
  def resolve(config) do
    # This is a placeholder for the actual Tailwind CSS resolve_config function
    # You'll need to implement or integrate with the actual Tailwind CSS resolver

    ## TODO
    resolved = base_resolve_config(config)

    %{
      resolved |
      prefix: Map.get(resolved, :prefix, ""),
      separator: Map.get(resolved, :separator, ":"),
      core_plugins: resolve_core_plugins(Map.get(resolved, :core_plugins, []))
    }
  end

  ## TODO build base_resolve_config, which is imported from tailwindcss/resolveConfig
  defp base_resolve_config(config) do
    config
  end

  defp resolve_core_plugins(core_plugins) when is_list(core_plugins) do
    Enum.reduce(core_plugins, %{}, fn plugin, acc ->
      Map.put(acc, String.to_atom(plugin), true)
    end)
  end
end
