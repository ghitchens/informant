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

- [ ] is there one informant registry, or are there multiple "domains"?  If so, how do associated registries get started?  What gets started with the app?

## Remaining small implementation details

- [ ] apply_changes/2 needs to properly compute changesets based on appropriate
      strategy.  It currently just does Map.merge.

## Not Yet Implemented - Should we?

- [ ] Is it appropriate to have source defined as source_spec | delegate_pid?  It adds a bit of confusion to the API.   Would it be better to always use source for publish() and delegates for unpublish(), inform(), update(), and sync_update()?

Features not implemented yet, and not sure if we need yet

- [ ] **Domains** are ways of classifying different registries.  A process could
  subscribe to multiple sources in different domains, but a single subscription
  would only be valid in a single domain.    In other words, a non-matchable way
  of separating the namespace of sources.  

  - If there are multiple registries, how do they get started -- i.e. is there one general one started with the informant app, or do they get started as requested during publish() and subscribe()?

- [ ] **Anonymous Sources** would allow a source to not have a linked process, and to exist until explicitly removed.  Any process could update its public state or send events from it.  Do we have a use case for them that is compelling enough to warrant the potential bugs of zombie sources?

- [ ] **Filters** are an additional matchspec on a subscription to match only a subset of notifications from a specific source, preventing mailboxes from churning with messages that are going to be ignored by a subscriber.  Are they that useful?
