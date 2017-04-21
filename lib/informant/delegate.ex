defmodule Informant.Delegate do

  @moduledoc false

  defmodule State, do: defstruct(
    subscribers: %{},
    pubstate: %{},
    source_pid: nil,
    domain: nil,
    topic: nil,
    options: []
  )

  def start_link(args) do
    GenServer.start(__MODULE__, args)
  end

  ## Server Callbacks

  def init({domain, topic, options, source_pid}) do
    Process.flag(:trap_exit, true)
    Registry.register(registry_for(domain), :sources, {topic, source_pid})
    subscribers = Informant.subscriptions_matching(domain, topic)
    GenServer.cast self(), {:announce, {:init, topic}}
    state = %State{
      pubstate: options[:pubstate] || %{},
      source_pid: source_pid,
      topic: topic,
      domain: domain,
      subscribers: subscribers,
      options: options
    }
    {:ok, state}
  end

  def handle_cast({:do_inform, message}, state) do
    notify_subscribers(message, state)
    {:noreply, state}
  end
  def handle_cast({:do_update, changeset, metadata}, state) do
    {new_pubstate, changes} = apply_changeset(state.pubstate, changeset)
    notify_subscribers({:changes, changes, metadata}, state)
    {:noreply, %{state | pubstate: new_pubstate}}
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    notify_subscribers(:exit, state)
    {:noreply, state}
  end


  ## Helpers

  # NYI BUG Bad implementation doesn't really compute actual changes yet
  @spec apply_changeset(map, map) :: {map, map}
  defp apply_changeset(oldstate, changeset) do
    newstate = Map.merge(oldstate, changeset)
    {newstate, changeset}
  end

  defp notify_subscribers(message, state) do
    for {pid, opts} <- state.subscribers do
      send(pid, {:notify, message, opts}) # TODO proper opts?
    end
  end

  defp registry_for(domain) do
    Module.concat(Registry.Informant, domain)
  end

end
