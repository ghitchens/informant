defmodule Informant.Domain do

  @moduledoc """
  Used by the Informant module to manage a directory of topics and subscriptions
  and their associated processes related to a common domain.

  REVIEW:   Current implementation delegates a lot to Registry, but not clear if
            a single registry can provide sufficent performance, specifically for
            finding topics in lookup_topic/2 and topics_matching_subscription/2
  """

  @registry Registry.Informant
  @type domain :: atom
  @type subscription :: {term, term}
  @type topic :: {term, term}

  def start_link(domain) do
    Registry.start_link(:duplicate, registry(domain))
  end

  def subscribe(domain, subscription, options) do
    Registry.register(registry(domain), subscription, options)
  end

  def unsubscribe(domain, subscription) do
    Registry.unregister(registry(domain), subscription)
  end

  @doc "add the current pid as delegate for the topic"
  def register_topic(domain, topic) do
    Registry.register(registry(domain), Informant.Topics, topic)
  end

  @doc "Given a topic, return {pid, topic}"
  @spec lookup_topic(domain, topic) :: {pid, topic}
  def lookup_topic(domain, topic) do
    # REVIEW: Horrible implementation, needs better plan than Registry.match
    #         on the topic, since that's a linear search
    case Registry.match(registry(domain), Informant.Topics, topic) do
      [] -> {:error, :notfound}
      [{delegate, ^topic}] -> {delegate, topic}
    end
  end

  @doc "Return list of {pid, topic} tuples that match the given subscription"
  @spec topics_matching_subscription(domain, subscription) :: [{pid, topic}]
  def topics_matching_subscription(domain, subscription) do
    Registry.match(registry(domain), Informant.Topics, subscription)
  end

  @doc "Return list of {pid, subscription} tuples that match the given topic"
  @spec subscriptions_matching_topic(domain, topic) :: [{pid, subscription}]
  def subscriptions_matching_topic(domain, {a, b}) do
    r = registry(domain)
    ( Registry.lookup(r, {a, b}) ++ Registry.lookup(r, {a, :_}) ++
      Registry.lookup(r, {:_, b}) ++ Registry.lookup(r, {:_, :_}) )
  end

  # internal helpers

  defp registry(domain), do: Module.concat(@registry, domain)

end
