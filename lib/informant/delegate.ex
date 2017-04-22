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
    notify(subscribers, {:init, domain, topic, self()})
    {:ok, %State{
      pubstate: options[:pubstate] || %{},
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
    notify state.subscribers, message
    {:noreply, state}
  end
  def handle_cast({:update, changeset, metadata}, state) do
    case apply_changeset(state.pubstate, changeset) do
      {changes, _} when changes == %{} ->
        {:noreply, state}
      {changes, new_pubstate} ->
        notify state.subscribers, {:changes, changes, metadata}
        {:noreply, %{state | pubstate: new_pubstate}}
    end
  end
  def handle_cast({:subscribe, subscriber, data}, state) do
    notify [subscriber], {:subscribed, state.topic, data}
    {:noreply, %{state | subscribers: state.subscribers ++ [subscriber]}}
  end

  def handle_call({:update, changeset, metadata}, _from, state) do
    case apply_changeset(state.pubstate, changeset) do
      {changes, _} when changes == %{} ->
        {:reply, :nochanges}
      {changes, new_pubstate} ->
        notify state.subscribers, {:changes, changes, metadata}
        {:reply, {:changes, changes, new_pubstate}, %{state | pubstate: new_pubstate}}
    end
  end

  def handle_info({:EXIT, pid, reason}, state) do
    notify state.subscribers, {:exit, pid, reason}
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

  defp notify(subscribers, message) do
    for {pid, opts} <- subscribers do
      send(pid, {:notify, message, opts}) # TODO proper opts?
    end
  end

end
