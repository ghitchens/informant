defmodule Informant do

  @moduledoc """
  A system to distribute published state and notifications to local
  subscribing processes, emphasizing concurrency, performance and proper
  sequencing.
  
  Informant manages a directory of _sources_ of published state and events,
  and a list of _subscriptions_, created by processes that want to receive
  notifications about sources.  Subscriptions can include wildcards, matching
  multiple sources.
  
  Suscribers receive notifications about events and changes to the source's
  published state via messages sent to the subscriber's mailbox, as well as
  notifications about new sources and exiting sources that match the
  subscription.

  # Important Characteristics

  - Subscriptions are independent of sources; subscriptions can come before or
    after the source is published in the directory.  Wildcards can be used
    subscribe to multiple sources.
    
  - Informant provides a cached key/value store for each source that holds the
    "published state" for each source.
  
  - Allows processes to subscribe one or more sources in the directory, 
    thereby receiving notifications of changes to that source's published
    state, as well as any stateless events sent by the source.
    
  - Publishing changes to state or sending an event are very light weight
    and do not block the source process at all, ensuring high performance
    even in light of heavy notification usage.
    
  - Atomicity and correct sequencing of all notifications are preserved,
    both during subscription and when interspersed with queries of state, due
    to the use of delegate processes which sequence gets and event sends for
    each source.

  - Notifications are sent to subscribers when sources that match a
    subscription are published, including their published state.
    
  - Notifications are also sent when a source process exits (normally or
    abnormally), so any subscribed state can be considered invalid.

  - Each source has a corresponding _delegate_ that manages distributing
    events and state change notifications for that source and it's 
    source process.

  TODO is there one informant regsistry, or multiple?
       multiple, we call them domains, but how do registries get started?
       what can you subscribe to with wildcards?
       System, Nerves.NetworkInterface, "eth0", {:ip, _}
  """

  @type domain :: atom
  @type topic :: any
  @type instance :: any
  @type source :: {domain, topic, instance} | pid
  @type source_matchspec :: {domain | :_, topic | :_, instance | :_}
  @type subcriber :: pid
  @type sourcepid :: pid

  @doc """
  Publishes a source of information under the keys given in `source`.

  `source` is always formatted as a 3-element tuple {domain, topic, instance}.

  ## Examples

      Informant.publish {Nerves.Networking, :settings, :eth0}, 
                        %{ip: "192.168.15.2", router: "192.168.15.1"}

  * `:anonymous` - do not assign the current process as the owner of the
     source.  This means the source entry will not be tied to any entry

  ## Internals 

  Starts a delegate process, registers it under the specified domain and
  topic, sets up subscribers, and sends initial notifications.
  """
  @spec publish(source, Keyword.t) :: {:ok, source} | {:error, reason}
  def publish(source, opts \\ []) do
    GenServer.start_link Delegate, {self(), domain, topic, opts}, name: name
  end
  def publish(source, opts \\ []) when is_list(opts) do
    register(domain, pid_to_dynamic_topic(self()), opts)
  end

do

  @doc """
  Unpublish the source, terminating its informant, and sending a final
  notification for each.  Note that if the source terminates, it's
  informant is terminated automatically.
  """
  def unpublish(source) do
  end


  @doc """
  Send a notification to all processes subscribing to the specified source.
  By default, this notification comes from the current process.
  """
  @spec announce(event) :: :ok
  def announce(event, source \\ self())

  @spec subscribe(source_matchspec, Keyword.t) :: {:ok, subscribe_info}
  def subscribe(source_matchspec, options \\ [])


  @doc ~S"""
  Manages distribution of notifications from registered or anonymous sources.

  Updates public state with `updates`, computes and returns changes,

  and then triggers notifications.  Nonblocking/nonpre-emptive.


  """

  ## APPLICATION

  def start_link() do

  end

  ## Subscription API

  @doc """
  Subscribe the current process to be informed by all current and future
  published informants that match the specification and filters in
  subscription.

  # subscribe to everythin from Nerves.NetworkInterface
  subscribe(Nerves.NetworkInterface, :_, :_)

  # subscribe only to topics coming and going
  subscribe(Nerves.NetworkInterface, :_, {:topic, _})
  """
  def subscribe(subscription_matchspec, optioons \\ nil) do
    Registry.register(@registry, :subscriptions, {subscription, args})
    for {pid, whatever} <- Registry.match(__MODULE__, :sources) do
      GenServer.cast pid, {:subscribe, self(), {subscription, args}}
    end
  end

  ## Publisher API

    GenServer.stop(informant)
  end

  ##
  ## Source Event API

  @doc """
  Send a notification to all listeners for this informant
  """
  @spec announce(informant, event) :: :ok
  def announce(informant, event) do
    GenServer.cast(informant, {:announce, event})
  end

  ## Source Data API (NYI)

  def update(informant, changes) do
    GenServer.call(informant, {:update, changes})
  end

  def get(informant) do
    GenServer.call(informant, :get, :key)
  end

end
