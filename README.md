# Informant

A system to distribute notifications of state changes and events.

Informant allows processes that want to provide public state (sources) to publish that state and associated events, organized as topics.  Other processes can then add a subscription to one or more topics, including wildcard subscriptions, thereby getting notified of state changes, events, and other metadata about the matching topics.

Subscribers receive notifications about events and changes to the source's
published state via messages sent to the subscriber's mailbox, as well as
notifications about matching topics coming and going.

All subscribers are notified of topics that match their subscription including initial state, as well as new processes that join, and processes that exit.

Informant manages one or more _topics_, organized into _domains_.  Processes
which are sources for events can publish one more of these topics on a domain.


## Terminology

  **Source** :: a processes that announces state or sources events by publishing one or more _topics_.

  **Topics** :: a key that can be subscribed or published. Consist of 2-tuples, each of which can be subscribed to with a wildcard.   A single source can publish more than one topic, but only one source can exist per topic, (caveat in TODO).

  **Domains** :: an Atom that organizes a list of topics, separating the
  namespace.  

  **Subscription** :: An expressed interest in one or more topics. Subscribers receive notifications for topics they that match their subscription.

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

## Message Format

All messages from informant are delivered to subscriber's mailbox from the
delegate process, as a 5-tuple of the form:

```elixir
{:informant, domain, topic, notification, subscription_data}
```

`subscription_data` is any term passed from the subscriber via the `data:` option during subscription.  

### Notification Types

```elixir
{:join, state, status(:published | :subscribed)}
```
Sent when a topic is new to a subscriber, along with its initial state.  This can happen either when a topic matching an existing topic has just been published (in which case status will be :published), or when a subscription matches an existing topic (in which case status will be :subscribed)

```elixir
{:exit, reason}
```
Sent when a topic exits.  This is NOT sent during an unsubscribe, since the assumption is that the un-subscriber knows the topic is no longer available (REVIEW - not sure this is best choice).

```elixir
{:changes, changes, metadata}    
```

## Examples

See tests for now.

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
with the app?  Is it OK to say "nothing", and that domains are created by the things that "publish" things on them?  I.E. the Networking domain gets created
somehow as part of bringing up the network infrastructure?

#### Features not yet implemented, possibly not needed

- [ ] **Anonymous Sources** would allow a source to not have a linked process, and to exist until explicitly removed.  Any process could update its public state or send events from it.  Do we have a use case for them that is compelling enough to warrant the potential bugs of zombie sources?

- [ ] **Filters** are an additional matchspec on a subscription to match only a subset of notifications from a specific source, preventing mailboxes from churning with messages that are going to be ignored by a subscriber.  Are they that useful?

#### Remaining small implementation details

- [ ] lookup_topic and topics_matching_subscription are slow and need
      proper indexing or table structure

- [ ] review proper sequencing of subscribe/unsubscribe messages
