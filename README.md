# Informant

An exploration of a concurrent event and state distribution system.

Informant is a work in progress, this is a first cut exploration of what might replace Hub.   As of Friday, 21-Apr-2017, it is not ready for evaluation,
as it doesn't yet pass tests.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `informant` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:informant, "~> 0.1.0"}]
end
```
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/informant](https://hexdocs.pm/informant).

## Remaining Big Questions

- [ ] how do domains get setup in a real world system?  What gets started
with the app?

## Remaining small implementation details

- [ ] apply_changes/2 needs to properly compute changesets based on appropriate
      strategy.  It currently just does Map.merge.

- [ ] lookup_topic and topics_matching_subscription are slow and need
      proper indexing or table structure

## Features not yet implemented, possibly not needed

- [ ] **Anonymous Sources** would allow a source to not have a linked process, and to exist until explicitly removed.  Any process could update its public state or send events from it.  Do we have a use case for them that is compelling enough to warrant the potential bugs of zombie sources?

- [ ] **Filters** are an additional matchspec on a subscription to match only a subset of notifications from a specific source, preventing mailboxes from churning with messages that are going to be ignored by a subscriber.  Are they that useful?
