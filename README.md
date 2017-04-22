# Informant

A concurrent event and state distribution system.

Distributes notifications about state and events from sources to subscribers.

Informant manages a directory of _sources_ which publish state and provide
events, and a list of _subscriptions_, created by processes that want to
receive notifications about matching topics, and the events and changes to state of their associated sources.

Suscribers receive notifications about events and changes to the source's
published state via messages sent to the subscriber's mailbox, as well as
notifications about matching sources coming and going.

## Terminology

  **Sources** are processes that publish topics.  Any given topic can be
  published by only one source (for now, todo for anonymous sources below).
  For instance, `Nerves.NetworkInterface` might have a single process per
  interface -- those processes would be sources.

  **Topics** consist of 2-tuples, each of which can be subscribed to with a
  wildcard.   A single source can publish more than one topic, but only
  one source can exist per topic, (caveat in TODO).

## Important Characteristics

- Each published source is managed by a _delegate process_, which caches
  published state and properly sequences both requests for state and
  notifications.  This allows performant, concurrent event and state
  distribution without race conditions.

- Subscriptions are independent of sources, may contain wildcards to match
  multiple sources, and can happen before or after the source is published.

- Subscribers are notified of published sources (and current public state)
  upon subscription, and of newly matching sources (and initial public state)
  when those sources are published. Sources also notify their subscribers when
  they exit.

- Informant optimizes event dispatch. Public state changes and notifications
  are nonblocking and fast at the expense of more complex subscription and
  publishing.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `informant` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:informant, "~> 0.1.0"}]
end
```
Documentation can soon be found at [https://hexdocs.pm/informant](https://hexdocs.pm/informant).  But not yet :)

## To Do

#### Remaining Big Questions

- [ ] how do domains get setup in a real world system?  What gets started
with the app?

#### Remaining small implementation details

- [ ] apply_changes/2 needs to properly compute changesets based on appropriate
      strategy.  It currently just does Map.merge.

- [ ] lookup_topic and topics_matching_subscription are slow and need
      proper indexing or table structure

#### Features not yet implemented, possibly not needed

- [ ] **Anonymous Sources** would allow a source to not have a linked process, and to exist until explicitly removed.  Any process could update its public state or send events from it.  Do we have a use case for them that is compelling enough to warrant the potential bugs of zombie sources?

- [ ] **Filters** are an additional matchspec on a subscription to match only a subset of notifications from a specific source, preventing mailboxes from churning with messages that are going to be ignored by a subscriber.  Are they that useful?
