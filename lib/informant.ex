defmodule Informant do

  @doc ~S"""
  Manages distribution of notifications from registered or anonymous sources.

  Updates public state with `updates`, computes and returns changes,
  and then triggers notifications.  Nonblocking/nonpre-emptive.

  # Important Characteristics

  - Atomicity of complex update notifications
  - Atomicity of notifications upon subscription
  - Subscription to multiple sources via wildcards
  - Subscriptions can

  publisher

  *source* : a publisher (synonym?) process that sources state and notifications
             of changes in state.   The registry links to the source process,
             so that terminating processes invalidate public state.

  *anonymous source* : a special source that doesn't refer to an actual process,
                       and is not linked to a process.

  follower(())

  subscriber - a process that receives notifications from a publisher
  listener - a process that receives notifications from a source

  WARNNING:  I have not convinced myself that this is concurrentcy-safe.
  Can a pre-emption happen between safely_update.... and notify?
  Can another notification be sent at this time?  Or is the calling
  process responsible for serializing updates?

  listen() follow() observe() watch() subscribe() track() monitor() spy() tap()
  publish() register()
  inform() update() notify()



  TODO how do we delete things when sources crash?  are things linked?

  """
  use GenServer

  ## API

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Follow notifications from one or more sources.

  the current process to receive notifications from all
  registered sources (current and future) that match sourcespec.

  Notifications from these processes will be filtered based on "filterspec".

  Specifies that the current process is to recThe current process is  a receiver of notifications from one or
  more sources in the current registry, with an optional event filter.

  e.g. Informant.follow(Nerves.NetworkInterace, "eth0")

  TODO: subscribes should go into a subscriptions table that is handled when new sources
  are published, so that wildcard subscriptions for sources can match new sources when they
  get published.
  """
  @spec follow(atom, any, any) :: {:ok, any} | {:error, reason}
  def follow(registry, sourcespec, filterspec \\ nil) do
    GenServer.call __MODULE__, {:follow, sourcespec, filterspec}
  end

  @doc """
  Return a map of sources and current states
  """
  def find(registry, sourcespec) do

  end

  def notify(registry, source, notification) do
    GenServer.call __MODULE__, {:notify, }
  end


  ## Server

  def init() do
    {:ok, state}
  end

  def handle_call({:follow, sourcespec, filterspec}, _from, state) do


  end
    Registry.register(registry, :followers, filterspec)


    :ets.insert(:followers, ), arg2)add_follow(followers)
    Registry.match(registry, topics, sourcespec)

    Registry.register(registry, key, filter)
  end


  @doc """
  Register a souce with a registry, and set its state.
  If source is already published on this registry, replace its state with the
  one given here.
  """
  def publish(registry, source, state) do

  end

  @doc """
  Update the values for
  """


  end

  def inform(registry, topic, changes)
    case Registry.dispatch(registry, topic, fn entries ->
      for {pid, {module, function}} <- entries
    end
  end

  Registry.dispatch Nerves.NetworkInterface, data.ifname, fn entries ->
    for {pid, _filters} <- entries do

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
