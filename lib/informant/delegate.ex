defmodule Informant.Delegate do

  @moduledoc """
  Defines a GenServer process that handles all the work of managing
  interactions between a _source_ and the rest of the world.
  """

  def start_link(args) do
    GenServer.start(__MODULE__, args)
  end

  ## Server Callbacks

  def init({source_pid, domain, topic, opts}) do
    Process.flag(:trap_exit, true)
    subscribers = :ets.new sourceid(topic, source_pid), [:set]
    Registry.register(__MODULE__, :sources, {topic, source_pid})
    listeners = current_subscribers_for(topic)
    GenServer.cast self(), {:announce, {:init, topic}}
    {:ok, state}
  end

  def handle_cast({:announce, notification}, state) do
    notify_listeners(notificaton, state)
    {:ok, state}
  end

  def handle_info({:EXIT, pid, _reason}, state) do
    notify_listeners(:exit, state)
    {:ok, state}
  end

  def handle_info(msg, state) do
    super(msg, state)
  end

  ## Helpers

  defp notify_listeners(notification, state) do
    for {pid, opts} <- matching_listeners(state, notification) do
      send(pid, {:notify, notification, opts}) # TODO proper opts?
    end
  end

  defp pid_to_dynamic_topic(pid) do
    pid
    |> :erlang.pid_to_list
    |> :erlang.list_to_atom
  end

  defp informant_name(domain, topic) do
    Module.concat(domain, topic)
  end

end
