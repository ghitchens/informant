defmodule Informant.Domain do

  @moduledoc false

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

  # add the current pid as delegate for the topic
  def register_topic(domain, topic) do
    Registry.register(registry(domain), Informant.Topics, topic)
  end

  @spec topics_matching_subscription(domain, subscription) :: [{pid, topic}]
  def topics_matching_subscription(domain, subscription) do
    Registry.match(registry(domain), Informant.Topics, subscription)
  end

  @spec subscriptions_matching_topic(domain, topic) :: [{pid, subscription}]
  def subscriptions_matching_topic(domain, {a, b}) do
    r = registry(domain)
    ( Registry.lookup(r, {a, b}) ++ Registry.lookup(r, {a, :_}) ++
      Registry.lookup(r, {:_, b}) ++ Registry.lookup(r, {:_, :_}) )
  end

  # internal helper for registries
  def registry(domain), do: Module.concat(@registry, domain)

end
