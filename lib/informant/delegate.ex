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
    notify(state.domain, state.topic, state.subscribers, message)
    {:noreply, state}
  end

  # sent by source (only) to update public state of the topic
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

  # Cast by Informant.subscribe to add subscriber
  def handle_cast({:subscribe, subscriber, subargs}, state) do
    if Map.has_key?(state.subscribers, subscriber) do
      {:noreply, state}
    else
      notify(state.domain, state.topic, [{subscriber, subargs}], {:join, state.pubstate, :subscribed})
      {:noreply, %{state | subscribers: Map.put(state.subscribers, subscriber, subargs)}}
    end
  end

  # Invoked by Informant.request/3, this casts the request to the source, and
  # assumes the source will notify us if it wants to  update.
  def handle_cast({:request, request}, state) do
    GenServer.cast(state.source_pid, request_msg(request, state))
    {:noreply, state}
  end

  # Invoked by Informant.sync_update/3 to set the public state of this topic
  # respond with {:changes, changeset, new_public_state}
  def handle_call({:update, changeset, metadata}, _from, state) do
    {changes, new_state} = apply_and_notify(changeset, metadata, state)
    {:reply, {:changes, changes}, new_state}
  end

  # Called by Informant.state() to get public state of this topic
  def handle_call(:state, _from, state) do
    {:reply, state.pubstate, state}
  end

  # Invoked by Informant.sync_request/3 to synchronously update the
  # source, passing the request to the source process, and then
  # generating a changeset that is returned.
  def handle_call({:request, request}, _from, state) do
    GenServer.call(state.source_pid, request_msg(request, state))
    |> case do
      {:update, changeset, metadata} ->
        {changes, new_state} = apply_and_notify(changeset, metadata, state)
        {:reply, {:changes, changes, metadata}, new_state}
      other -> raise "#{inspect other}"
    end
  end

  def handle_info({:EXIT, pid, reason}, state) do
    notify(state.domain, state.topic, state.subscribers, {:exit, pid, reason})
    {:noreply, state}
  end

  ## Helpers

  defp request_msg(request, state) do
    {:request, request, {state.domain, state.topic}}
  end

  defp notify(domain, topic, subscribers, message) do
    for {pid, subscriber_args} <- subscribers do
      send(pid, {:informant, domain, topic, message, subscriber_args})
    end
  end

  # Apply changeset, send notifications, return {changes, newstate}
  @spec apply_and_notify(map, map, term) :: {map, term}
  defp apply_and_notify(changeset, metadata, state) do
    {changes, new_pubstate} = apply_changeset(state.pubstate, changeset)
    notify(state.domain, state.topic, state.subscribers, {:changes, changes, metadata})
    {changes, %{state | pubstate: new_pubstate}}
  end

  # Determine which changes in `requested` changes are actually changes
  # to the given map, return {changed, newmap}.
  @spec apply_changeset(map, map) :: {map, map}
  defp apply_changeset(map, requested) do
    changed = :maps.filter(&(map[&1] != &2), requested)
    {changed, Map.merge(map, changed)}
  end

end
