defmodule Informant.Delegate do

  @moduledoc false
  alias Informant.Domain

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
    Domain.register_topic(domain, topic)
    Process.flag(:trap_exit, true)
    subscribers = Domain.subscriptions_matching_topic(domain, topic)
    pubstate = options[:state] || %{}
    notify(domain, topic, subscribers, {:join, pubstate, :published})
    {:ok, %State{
      pubstate: pubstate,
      source_pid: source_pid,
      topic: topic,
      domain: domain,
      subscribers: subscribers,
      options: options}}
  end

  def terminate(_reason, _state) do
    :ok
  end

  def handle_cast({:inform, message}, state) do
    notify state.domain, state.topic, state.subscribers, message
    {:noreply, state}
  end
  def handle_cast({:update, changeset, metadata}, state) do
    case apply_changeset(state.pubstate, changeset) do
      {changes, _} when changes == %{} ->
        {:noreply, state}
      {changes, new_pubstate} ->
        notify(state.domain, state.topic, state.subscribers,
          {:changes, changes, metadata})
        {:noreply, %{state | pubstate: new_pubstate}}
    end
  end
  def handle_cast({:subscribe, subscriber, subargs}, state) do
    notify(state.domain, state.topic, [{subscriber, subargs}],
          {:join, state.pubstate, :subscribed})
    subscribers = state.subscribers ++ [{subscriber, subargs}]
    {:noreply, %{state | subscribers: subscribers}}
  end

  def handle_call({:update, changeset, metadata}, _from, state) do
    case apply_changeset(state.pubstate, changeset) do
      {changes, _} when changes == %{} ->
        {:reply, :nochanges}
      {changes, new_pubstate} ->
        notify(state.domain, state.topic, state.subscribers, {:changes, changes, metadata})
        {:reply, {:changes, changes, new_pubstate}, %{state | pubstate: new_pubstate}}
    end
  end
  def handle_call(:state, _from, state) do
    {:reply, state.pubstate, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    notify(state.domain, state.topic, state.subscribers, {:exit, pid, reason})
    {:noreply, state}
  end

  ## Helpers

  # Determine which changes in `requested` changes are actually changes
  # to the given map, return {changed, newmap}.
  @spec apply_changeset(map, map) :: {map, map}
  defp apply_changeset(map, requested) do
    changed = :maps.filter(&(map[&1] != &2), requested)
    {changed, Map.merge(map, changed)}
  end

  defp notify(domain, topic, subscribers, message) do
    for {pid, subscriber_args} <- subscribers do
      send(pid, {:informant, domain, topic, message, subscriber_args})
    end
  end

end
