# Informant <small>(experimental)</small>

A system for handling local pub/sub of state and events.

Informant allows Elixir processes (_source processes_) to publish _topics_ that
provide access to _public state_ and _events_. Other processes may _subscribe_
to a topic or a wildcard group of topics, resulting in notifications of matching
topic's public state and events being sent to the
subscriber's mailbox.  

Informant is designed for fast, concurrent event dispatch with proper sequencing
and no locks at the expense of slightly slower subscription and publishing.
Source processes incur the cost of a single message send to update their public
state, and transactions or event dispatch on a topic do not block any other topics.  

Informant's API is still experimental and subject to frequent change.

## Example

A taste of usage follows.  Please see `test/informant_test.exs` for more.

```elixir
# start the Networking domain
iex(1)> Informant.start_link(Networking)
{:ok, #PID<0.108.0>}

# publish a topic called {:settings, "eth0"}x
iex(2)> {:ok, eth0} = Informant.publish(Networking, {:settings, "eth0"},
state: %{ipv4_address: "192.168.1.101", ipv4_subnet_mask: "255.255.255.0"})
{:ok, #PID<0.113.0>}

# now query the public state of the topic
iex(3)> Informant.state(Networking, {:settings, "eth0"})
%{ipv4_address: "192.168.1.101", ipv4_subnet_mask: "255.255.255.0"}

# make sure there are no messages in the mailbox
iex(4)> flush()
:ok

# subscribe to a wildcard for all settings in networking
iex(5)> Informant.subscribe(Networking, {:settings, :_})
{:ok, #PID<0.109.0>}

# we get immediately notified of matching topics and their state
iex(6)> flush()
{:informant, Networking, {:settings, "eth0"}, {:join, %{ipv4_address: "192.168.1.101", ipv4_subnet_mask: "255.255.255.0"}, :subscribed}, nil}
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

## Terminology

Informant uses the following terminology to describe its behavior...

**Source** : A process that announces _public state_ or sources _events_ by publishing one or more _topics_ that can be _subscribed_ to.  A single source can publish more than one topic, but any given topic belongs to at most one source.

**Topic** :: A unit of subscription. Topics are identified by a 2-tuple key that is assigned at time of publishing, and can be matched by subscribers.  

**Subscription** :: An expressed interest in one or more topics.  A subscription may be to a single topic, or include wildcards for either or both of the terms of the 2-tuple topic identifier, matching multiple topics.  Subscribers receive notifications for topics they that match their subscription.

**Delegate** :: A process to manage a topic, linked to a source.  Every published topic has a single _delegate_ process that serializes all transactions, and handles messaging and subscriptions for that topic.

**Public State** :: A key-value store tied to a topic, cached in the delegate associated with a topic.  This is generally only directly updated by the source process that publishes the topic, but is readable at any time without locking any other topic, and without asking the source process.   Changes to public state made by the source cause notifications to be sent to subscribers.

**Domain** :: A registry of topics and subscriptions, identified by an atom. All topics, and subscriptions live in some Domain.   For instance, the `{:net, :eth0}` topic may be published in both the `Networking` domain and the `Printers` domain, but they are two distinct topics, and a subscription to one does not imply a subscription to the other.  

**Request** :: A way of asking a topic's source to make a change to its published state.  Requests can be sent either asynchronously (casted) or synchronously.  In the latter case, they are sequenced through the source's delegate, so that a source can respond and update and return modified state in sequence with other notifications.

## Implementation Characteristics

- Each published topic is managed by a unique _delegate process_, which caches published state and properly sequences both requests for state and notifications.  This allows performant, concurrent event and state distribution without race conditions.

- Subscriptions are completely independent of topics, may contain wildcards to match multiple topics, and can happen before or after the source is published.

- Subscribers are notified of published sources (and current public state) upon subscription, and of newly matching sources (and initial public state)
when those sources are published. Sources also notify their subscribers when
they exit.

- Informant optimizes event dispatch. Public state changes and notifications are nonblocking and fast at the expense of more complex subscription and publishing.

## Notifications

All messages from informant are delivered to subscriber's mailbox from the
delegate process, as a 5-tuple of the form:

{:informant, domain, topic, **notification**, subscription_data}

Where **notification** is one of...

**{:join, state, status(:published | :subscribed)}** - Sent when a topic is new to a subscriber, along with its initial state.  This can happen either when a topic matching an existing topic has just been published (in which case status will be :published), or when a subscription matches an existing topic (in which case status will be :subscribed)

**{:exit, reason}** - Sent when a topic exits.  This is NOT sent during an unsubscribe, since the assumption is that the un-subscriber knows the topic is no longer available (REVIEW - not sure this is best choice).

**{:changes, changes(map), metadata(map)}** - Sent when the public state of a topic changes.  Metadata is non-stateful data about the change, for instance a timestamp, and the meaning is entirely defined by the source.  `changes` is a map, as is `metadata`.

**{:event, event_id(atom), event_data(map)}** - An event without a corresponding change in state, for instance flagging an error that occurred.

## Installation

Informant can be installed by adding `informant` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:informant, "~> 0.1.0"}]
end
```
Documentation can be found at [https://hexdocs.pm/informant](https://hexdocs.pm/informant).

## Key Review Questions

- Is the terminology understandable?  Is there any of it that seems hard to make sense of?  What was hardest to understand at first?

- Do you see any use for anonymous sources?

## To Do List

Informant is still experimental.

#### Known implementation issues

- [ ] `lookup_topic` and `topics_matching_subscription` are slow due to pathologically poor implementation and need proper indexing or table structure.

- [ ] Review to ensure no races between `publish()` and `subscribe()` and introduce proper sequencing if needed.

#### Still to be implemented (needed?)

- [ ] **Anonymous Sources** would allow a source to not have a linked process, and to exist until explicitly removed.  Any process could update its public state or send events from it.  Do we have a use case for them that is compelling enough to warrant the potential bugs of zombie sources?

- [ ] **Filters** are an additional matchspec on a subscription to match only a subset of notifications from a specific source, preventing mailboxes from churning with messages that are going to be ignored by a subscriber.  Are they that useful?

#### Architectural Questions

- [ ] How do domains get setup in a real world system?  What gets started
with the app?  Is it OK to say "nothing", and that domains are created by the things that "publish" things on them?  I.E. the Networking domain gets created somehow as part of bringing up the network infrastructure?

#### Quip Design Notes

This contains a lot of old and outdated thinking (at the bottom) but can possibly be helpful in understanding the decisions made so far for Informant.

See  https://quip.com/XOy8A2xXozGA  

## Credits and History

- @fhunleth - for `Observables` and it's "wildcard" ideas
- `Elixir.Registry` on which this library builds
- `[Hub](https://github.com/nerves-project/nerves_hub)` which was one of my first attempts at state coordination in erlang (and subsequent port to elixir).  Lots of lessons learned.

## License

Licensed under the Apache License, Version 2.0
See the LICENSE file for more information.
