# Informant

A system for publishing and subscribing to state changes and events.

Informant allows Elixir processes to distribute public state and events by publishing _Topics_ that can be subscribed to.  Each topic may have associated _Public State_, which holds keys and values related to the topic.

Processes may _subscribe_ to one or more matching topics, including _Wildcard
Subscriptions_, thereby being notified of state changes, events, new topics, and other metadata from topics that match the subscription.

Informant is optimized for performant and concurrent event dispatch with proper sequencing.  Source processes incur the cost of a single message send to update their public state, with no locks, and transactions on a topic do not block other topics.  

## Example

This gives a taste of usage.   In this case, we both publish and subscribe from the same process, which is not a particuarly common scenario..

```elixir
# start the Networking domain
iex(1)> Informant.start_link(Networking)
{:ok, #PID<0.108.0>}

# publish a topic called {:settings, "eth0"}
iex(2)> {:ok, eth0} = Informant.publish(Networking, {:settings, "eth0"},
                                       state: %{ipv4_address: "192.168.1.101",
                                       ipv4_subnet_mask: "255.255.255.0"})
{:ok, #PID<0.113.0>}

# query the public state of the topic
iex(3)> Informant.state(Networking, {:settings, "eth0"})
%{ipv4_address: "192.168.1.101", ipv4_subnet_mask: "255.255.255.0"}

# make sure there are no messages in the mailbox
iex(4)> flush()
:ok

# subscribe to the topic we just created
iex(5)> Informant.subscribe(Networking, {:settings, "eth0"})
{:ok, #PID<0.109.0>}

# we got a join message
iex(6)> flush()
{:informant, Networking, {:settings, "eth0"},
 {:join, %{ipv4_address: "192.168.1.101", ipv4_subnet_mask: "255.255.255.0"},
  :subscribed}, nil}
:ok

# change the state of the topic with a new ip and subnet mask
iex(7)> Informant.update(eth0, %{ipv4_address: "192.168.1.15", ipv4_subnet_mask: "255.255.255.0"})
:ok

# notice we only got notified of the ip changing, because subnet is same.
iex(8)> flush()
{:informant, Networking, {:settings, "eth0"},
 {:changes, %{ipv4_address: "192.168.1.15"}, nil}, nil}
:ok
```

Please see test/informant_test.exs for deeper examples and features.

## Terminology

Informant uses the following terminology to describe its behavior...

**Source** : A process that announces _public state_ or sources _events_ by publishing one or more _topics_ that can be _subscribed_ to.  A single source can publish more than one topic, but any given topic belongs to at most one source.

**Topic** :: A unit of subscription. Topics are identified by a 2-tuple key that is assigned at time of publishing, and can be matched by subscribers.  

**Subscription** :: An expressed interest in one or more topics.  A subscription may be to a single topic, or include wildcards for either or both of the terms of the 2-tuple topic identifier, matching multiple topics.  Subscribers receive notifications for topics they that match their subscription.

**Delegate** :: A process to manage a topic, linked to a source.  Every published topic has a _delegate_ that serializes transactions, and handles messaging and subscriptions for that topic.

**Published State** :: A key-value store tied to a topic, cached in the delegate associated with a topic.  This is generally only directly updated by the source process that publishes the topic, but is readable at any time without locking any other topic, and without asking the source process.   Changes to public state made by the source cause notifications to be sent to subscribers.

**Domain** :: A registry of topics and subscriptions, identified by an atom. All topics, and subscriptions live in some Domain.   For instance, the `{:net, :eth0}` topic may be published in both the `Networking` domain and the `Printers` domain, but they are two distinct topics, and a subscription to one does not imply a subscription to the other.  

**Request** :: A systematic way of asking a source to make a change to its published state.  Because requests are sequenced through the delegate, they can update and return modified state in sequence with other notifications.

## Important Characteristics

- Each published topic is managed by a unique _delegate process_, which caches
  published state and properly sequences both requests for state and
  notifications.  This allows performant, concurrent event and state
  distribution without race conditions.

- Subscriptions are completely independent of topics, may contain wildcards to match
  multiple topics, and can happen before or after the source is published.

- Subscribers are notified of published sources (and current public state)
  upon subscription, and of newly matching sources (and initial public state)
  when those sources are published. Sources also notify their subscribers when
  they exit.

- Informant optimizes event dispatch. Public state changes and notifications
  are nonblocking and fast at the expense of more complex subscription and
  publishing.

## Informant Messages

All messages from informant are delivered to subscriber's mailbox from the
delegate process, as a 5-tuple of the form:

{:informant, domain, topic, **notification**, **subscription_data**}

Where `notification` is one of...

**{:join, state, status(:published | :subscribed)}** - Sent when a topic is new to a subscriber, along with its initial state.  This can happen either when a topic matching an existing topic has just been published (in which case status will be :published), or when a subscription matches an existing topic (in which case status will be :subscribed)

**{:exit, reason}** - Sent when a topic exits.  This is NOT sent during an unsubscribe, since the assumption is that the un-subscriber knows the topic is no longer available (REVIEW - not sure this is best choice).

**{:changes, changes, metadata}** - Sent when the public state of a topic changes.  Metadata is non-stateful data about the change, for instance a timestamp, and the meaning is entirely defined by the source.  `changes` is a map, as is `metadata`.

**{:event, event}** - An event without a corresponding change in state, for instance flagging an error that occurred.
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

## Questions

- Is the terminology understandable?  Is there any of it that seems hard to make sense of?  What was hardest to understand at first?

- Do you see any use for anonymous sources?

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
