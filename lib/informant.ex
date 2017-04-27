defmodule Informant do

  @moduledoc """
  Distributes notifications about state and events from sources to subscribers.

  See the README for more information for now.
  """

  @type domain :: atom
  @type instance :: any
  @type topic :: any
  @type changeset :: map
  @type pubstate :: map
  @type source_process :: pid
  @type key :: any
  @type reason :: any
  @type subscription :: {term, term}
  @type message :: any
  @type metadata :: any
  @type delegate :: pid
  @type subcriber :: pid
  @type request :: map
  @type request_response :: map
  @type resultset :: map

  alias Informant.Domain
  alias Informant.Delegate

  def start_link(domain) do
    Domain.start_link(domain)
  end

  ## Publisher API

  @doc """
  Registers the current process under `topic`, optionally declaring
  initial public state, returning a delegate process for the topic.

  ## Example

      Informant.publish Nerves.Networking, :settings, "eth0"}, %{
        ip: "192.168.15.2", router: "192.168.15.1", mask: "255.255.255.0"
      }
  """
  @spec publish(domain, topic, Keyword.t) :: {:ok, delegate} | {:error, reason}
  def publish(domain, topic, opts \\ []) do
    GenServer.start_link Delegate, {domain, topic, opts, self()}
  end

  @doc """
  Remove the source from the topic directory by asking its delegate to
  terminate, sending a final notification to all subscribers.
  Generally called by the process that published the topic.
  """
  @spec unpublish(delegate) :: :ok | {:error, reason}
  def unpublish(delegate) do
    GenServer.stop delegate
  end

  ## Subscription API

  @doc """
  Add a subscription to a topic or wildcard matching multiple topics.
  """
  @spec subscribe(domain, subscription, Keyword.t) :: {:ok, pid} | {:error, reason}
  def subscribe(domain, subscription, options \\ []) do
    case Domain.subscribe(domain, subscription, options) do
      {:ok, pid} ->
        for {delegate, _} <- Domain.topics_matching_subscription(domain, subscription) do
          GenServer.cast delegate, {:subscribe, self(), options[:subargs]}
        end
        {:ok, pid}
      other -> other
    end
  end

  @doc """
  Remove an existing subscription.
  """
  @spec unsubscribe(domain, subscription) :: {:ok, term}
  def unsubscribe(domain, subscription) do
    Domain.unsubscribe(domain, subscription)
  end

  ## Notification and Update API

  @doc """
  Send a `message` to the mailbox of all processes that subscribe to the
  topic represented by `delegate`.  The message will arrive in the following
  form:

    {:informant, {:inform, message}}

  The notification will always be sent from the process of the delegate.
  """
  @spec inform(delegate, message) :: :ok
  def inform(delegate, message) do
    GenServer.cast delegate, {:inform, message}
  end

  @doc """
  Updates public state for `delegate`, merging `changeset` into the
  delegate's public state cache.   The resulting changes are sent as
  a notification, along with metadata, to subscribers of the delegate's
  topic, in a message of the form:

    {:informant, {:update, changeset, metadata}}

  The notification will always be sent from the process of the delegate.
  """
  @spec update(delegate, changeset, metadata) :: :ok | {:error, reason}
  def update(delegate, changeset, metadata \\ nil) do
    GenServer.cast delegate, {:update, changeset, metadata}
  end

  @doc """
  Similar to `update/3`, but blocks and returns the changeset computed by the
  delegate.

  Returns {:changes, resultset} or {:error, reason}
  """
  @spec sync_update(delegate, changeset, metadata) :: {:changes, resultset} | {:error, reason}
  def sync_update(delegate, changeset, metadata) do
    GenServer.call delegate, {:update, changeset, metadata}
  end

  @doc """
  Return all keys/values from the delegate's public state, as a single map.

  This is propery sequenced so that if called from a subscriber, the response
  will arrive in the correct sequence with event notifications, avoiding race
  conditions.
  """
  @spec state(delegate) :: map | {:error, reason}
  def state(delegate) when is_pid(delegate) do
    GenServer.call(delegate, :state)
  end

  @doc """
  Return all keys/values from a topic's state, as a single map.

  See also state/1.
  """
  @spec state(domain, topic) :: map
  def state(domain, topic) when is_atom(domain) do
    Domain.delegate_for_topic(domain, topic)
    |> state()
  end

  @doc """
  Make a request of a topic's source.

  Generally this is used to ask a source ot change it's state in some way.
  Examples might include asking for a network adapter to change it's IP
  address or an audio player source process to change its volume.

  Done as a casted message, so always returns :ok.  If the source changes
  its public state, due to this request, subscribers are notified.
  """
  @spec request(domain, topic, request) :: :ok
  def request(domain, topic, request) when is_atom(domain) do
    Domain.delegate_for_topic(domain, topic)
    |> GenServer.cast({:request, request})
  end

  @doc """
  Make a synchronous request of a topic's source, returning changes..

  Similar to request/4, but returns the resulting chagnes to the
  source's public state.   In order to ensure proper sequencing,
  the request handled as a GenServer.call of the delegate, which in turn
  does a GenServer.call of the source.

  Returns {:changes, changes, metadata}
  """
  @spec sync_request(domain, topic, request) :: request_response
  def sync_request(domain, topic, request) when is_atom(domain) do
    Domain.delegate_for_topic(domain, topic)
    |> GenServer.call({:request, request})
  end

  @doc """
  Return a list of topics and their associated state, allowing wildcards in the
  topic lookup.
  REVIEW: parallelism might help here since we could make multiple calls
  """
  @spec lookup(domain, topic) :: [{topic, pubstate}]
  def lookup(domain, topic) do
    topics = Domain.topics_matching_subscription(domain, topic)
    Enum.map(topics, fn({pid, topic}) -> {topic, state(pid)} end)
  end

  @doc """
  Return the value of a single key from the delegate's public state.
  """
  @spec get(delegate, key) :: map | {:error, reason}
  def get(delegate, key) do
    GenServer.call(delegate, {:get, key})
  end

end
