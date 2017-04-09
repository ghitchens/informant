
  defmodule Informant do

  @moduledoc """
  Beginnings of exploration for something to replace Hub
  """

  def inform(_changes) do
  end

  @doc """
  Register to get events.

  Informant.register(Nerves.NetworkInterace, "eth0")
  """
  def subscribe(registry, topic, filter \\ nil) do
    Registry.register(registry, key, filter)
  end

  def inform(registry, topic, changes)
    case Registry.dispatch(registry, topic, fn entries ->
      for {pid, {module, function}} <- entries
    end
  end

  Registry.dispatch Nerves.NetworkInterface, data.ifname, fn entries ->
    for {pid, _filters} <- entries do
      send(pid, {Nerves.NetworkInterface, notif, data})
    end
  end

  send publisher, :subscribe_init, registry, topic, filter}
  receive() do
    {:subscribe_ok, current_state} ->
      Registry.register(registry, topic, filter)
      send publisher, :subscribe_complete
    after 1000 -> :error
  end

end
