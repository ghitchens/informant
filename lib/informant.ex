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
  Remove the source from the sources directory by asking its delegate to terminate
  and sending a final notification.   Generally called by the process that published
  the source.
  """
  @spec unpublish(delegate) :: :ok | {:error, reason}
  def unpublish(delegate) do
    GenServer.stop delegate
  end

  ## Subscription API

  @doc """
  Add a subscription to notifications from all matching sources (current and
  future).
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
  Add a subscription to notifications from all matching sources (current and future)
  """
  @spec unsubscribe(domain, subscription) :: {:ok, term}
  def unsubscribe(domain, subscription) do
    Domain.unsubscribe(domain, subscription)
  end

  ## Notification and Update API

  @doc """
  Send a `message` to the mailbox of all processes that subscribe to the
  specified `source`.  This arrives as {:inform, message} to subscribers.

  `source`, can either be a source_spec or a delegate_pid.
  The notification will always be sent from the process of the delegate.
  """
  @spec inform(delegate, message) :: :ok
  def inform(delegate, message) do
    GenServer.cast delegate, {:inform, message}
  end

  @doc """
  Updates public state for `delegate`, merging `changeset` into the
  delegate's public state cache.   The resulting changes are sent as
  a notification, along with metadata, to subscribers, in a message of
  the form:

    {:inform, {:update, changeset, metadata}}

  The notification will always be sent from the process of the delegate.
  """
  @spec update(delegate, changeset, metadata) :: :ok | {:error, reason}
  def update(delegate, changeset, metadata \\ nil) do
    GenServer.cast delegate, {:update, changeset, metadata}
  end

  @doc """
  Similar to `update/3`, but blocks and returns the changeset computed by the delegate.

  Returns {:changes, changeset, newstate} or {:error, reason}
  """
  @spec update(delegate, changeset, metadata) :: {:changes, changeset, pubstate} | {:error, reason}
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
  def state(domain, topic) when is_atom(domain) do
    Domain.delegate_for_topic(domain, topic)
    |> state()
  end

  @doc """
  Return the value of a single key from the delegate's public state.
  """
  @spec get(delegate, key) :: map | {:error, reason}
  def get(delegate, key) do
    GenServer.call(delegate, {:get, key})
  end

end
