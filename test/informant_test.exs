defmodule InformantTest do
  use ExUnit.Case
  doctest Informant

  # some test data

  @ipv4_state0 %{ipv4_address: "192.168.1.101",
                 ipv4_subnet_mask: "255.255.255.0",
                 ipv4_router: "192.168.1.1",
                 ipv4_dns1: "192.168.1.1",
                 ipv4_dns2: "4.4.8.8"}

  test "domains can be created and their topics and associated state accessed" do
    # Start a test domain
    assert{:ok, _} = Informant.start_link(Networking)

    # Now publish a topic with current process as source
    {:ok, eth0} = Informant.publish(Networking, {:config, "eth0"})

    # Verify that no public state exists for the topic
    assert Informant.state(Networking, {:config, "eth0"}) == %{}

    # Publish some state for the topic
    Informant.update(eth0, %{ipv4_dns2: "4.4.4.4"})

    # Verify that we can query the topic for that information
    assert Informant.state(Networking, {:config, "eth0"}) == %{ipv4_dns2: "4.4.4.4"}
  end

  test "subscribers are notified when new matching topics are published" do
    # Start a test domain
    assert{:ok, _} = Informant.start_link(Networking)

    # add a subscriber (also this process)
    assert {:ok, _} = Informant.subscribe(Networking, {:config, "eth0"})

    # Should not get notification as no matching topics yet published
    refute_receive _

    # Publish self() as source for a topic that matches our subscription
    {:ok, _} = Informant.publish(Networking, {:config, "eth0"})

    # make sure we (as a subscriber, now) got a notification of the publish
    assert_receive {:informant, Networking, {:config, "eth0"}, {:join, _, :published}, _}
  end

  test "subscribers notified of matching topics already published" do
    # Start a test domain
    assert{:ok, _} = Informant.start_link(Networking)

    # Publish self() as source for a topic even though we're not subscribed yet
    assert {:ok, eth0} = Informant.publish(Networking, {:config, "eth0"})

    # Now, add a subscriber (also this process)
    assert {:ok, _} = Informant.subscribe(Networking, {:config, "eth0"})

    # Should get a notification that we subscribed ot that topic
    assert_receive {:informant, Networking, {:config, "eth0"}, {:join, _, :subscribed}, _}

    # make some state change to the topic
    assert :ok = Informant.update(eth0, %{ipv4_dns2: "4.4.4.4"})

    # make sure we got a notification of the state change
    assert_receive {:informant, _, _, {:changes, %{ipv4_dns2: "4.4.4.4"}, _}, _}
  end

  test "metadata can be sent with update notifications" do
    # setup
    assert {:ok, _} = Informant.start_link(Networking)
    assert {:ok, eth0} = Informant.publish(Networking, {:config, "eth0"})
    assert {:ok, _} = Informant.subscribe(Networking, {:config, "eth0"})
    assert_receive {:informant, Networking, {:config, "eth0"}, {:join, _, _}, _}

    # update our {:config, "eth0"} topic to have some data
    # this might happen, for instance, after the adapter gets a DHCP address
    # throw a timestamp in the metadata for the notification just for fun
    Informant.update(eth0, @ipv4_state0, %{at: DateTime.utc_now})

    # make sure (as a subscriber) that we got notifications of those changes
    assert_receive {:informant, _, _, {:changes, @ipv4_state0, %{at: _}}, _}
  end

  test "updates result in notifications, but only of what changes" do
    # setup
    assert {:ok, _} = Informant.start_link(Networking)
    assert {:ok, _} = Informant.subscribe(Networking, {:config, "eth0"})
    {:ok, eth0} = Informant.publish(Networking, {:config, "eth0"}, state: @ipv4_state0)
    assert_receive {:informant, Networking, {:config, "eth0"}, {:join, _, :published}, _}

    # Make an update to change part of the state
    Informant.update(eth0, %{ipv4_dns2: "4.4.4.4"})

    # We should receive a notification of exactly that change and no others
    assert_receive {:informant, Networking, {:config, "eth0"}, {:changes, %{ipv4_dns2: "4.4.4.4"}, _}, _}

    # Make a second update with the exact same change
    Informant.update(eth0, %{ipv4_dns2: "4.4.4.4"})

    # Ensure we receive no notification
    refute_receive _

    # Make a broad update back to initial state (sets many keys)
    Informant.update(eth0, @ipv4_state0)

    # We should only receive the notification of the actual changes
    assert_receive {:informant, Networking, {:config, "eth0"}, {:changes, %{ipv4_dns2: "4.4.8.8"}, _}, _}
  end

  test "wildcard subscriptions" do
    {:ok, _} = Informant.start_link(Networking)

    # Register for all IP adapter configuration changes
    Informant.subscribe(Networking, {:config, :_})

    # Check that we can tell when wlan0 comes online
    {:ok, wlan0} = Informant.publish(Networking, {:config, "wlan0"}, state: @ipv4_state0)

    # See that we got the notification due to wildcard subscription
    assert_receive {:informant, Networking, {:config, "wlan0"}, {:join, _, :published}, _}

    # Now make sure we see when eth0 comes online
    {:ok, _} = Informant.publish(Networking, {:config, "eth0"}, state: @ipv4_state0)
    assert_receive {:informant, Networking, {:config, "eth0"}, {:join, _, :published}, _}

    # Check that we get updates for wlan0 due to wildcard subscribe
    assert Informant.update(wlan0, %{ipv4_dns2: "4.4.4.4"})
    assert_receive {:informant, Networking, {:config, "wlan0"}, {:changes, %{ipv4_dns2: "4.4.4.4"}, _}, _}
  end

  test "can subscribe to wildcard topics before they are published" do
    assert{:ok, _} = Informant.start_link(Networking)

    # Now, add a subscriber, we shouldn't receive anything as no topic is matched
    assert {:ok, _} = Informant.subscribe(Networking, {:_, "eth1"})
    refute_receive _

    # Now publish two topics that match our subscriber and one that doesnt
    # and make sure we are notified of the proper two
    assert {:ok, _} = Informant.publish(Networking, {:config, "eth1"})
    assert {:ok, _} = Informant.publish(Networking, {:stats, "eth1"})
    assert {:ok, _} = Informant.publish(Networking, {:config, "eth0"})

    # Should get two join notifications for eth1 but none for eth0
    assert_receive {:informant, Networking, {:config, "eth1"}, {:join, _, :published}, _}
    assert_receive {:informant, Networking, {:stats, "eth1"}, {:join, _, :published}, _}
    refute_receive {:informant, Networking, {:config, "eth0"}, {:join, _, :_}, _}
  end

  test "subscribe to wildcard topics after publishing and receive proper events" do
    assert{:ok, _} = Informant.start_link(Networking)
    assert {:ok, config_eth0} = Informant.publish(Networking, {:config, "eth0"})
    assert {:ok, config_eth1} = Informant.publish(Networking, {:config, "eth1"})
    assert {:ok, _stats_eth1} = Informant.publish(Networking, {:stats, "eth1"})

    # Now, add a subscriber (also this process)
    assert {:ok, _} = Informant.subscribe(Networking, {:_, "eth1"})

    # Should get two join notifications for eth1 but none for eth0
    assert_receive {:informant, Networking, {:config, "eth1"}, {:join, _, :subscribed}, _}
    assert_receive {:informant, Networking, {:stats, "eth1"}, {:join, _, :subscribed}, _}
    refute_receive {:informant, Networking, {:config, "eth0"}, {:join, _, :subscribed}, _}

    # make some state change to subscribed eth0 which we're not subsribed to
    assert :ok = Informant.update(config_eth0, %{ipv4_dns2: "4.4.4.4"})
    assert :ok = Informant.update(config_eth1, %{ipv4_dns2: "4.3.2.1"})

    # make sure we got a notification of the state change for eth1 but not eth0
    refute_receive {:informant, Networking, {:config, "eth0"}, {:changes, %{ipv4_dns2: "4.4.4.4"}, _}, _}
    assert_receive {:informant, Networking, {:config, "eth1"}, {:changes, %{ipv4_dns2: "4.3.2.1"}, _}, _}

    # now subscibe to the topic {:stats, :_}
    assert {:ok, _} = Informant.subscribe(Networking, {:stats, :_})

    # make sure that we don't get join notification since we already joined
    # under a different subscription
    refute_receive {:informant, Networking, {:stats, _}, {:join, _, _}, _}
  end

  test "can find topics in registry and associated state" do
    # Start a test domain
    assert{:ok, _} = Informant.start_link(Networking)

    # Now publish 2 topics with current process as source
    assert {:ok, _eth0} = Informant.publish(Networking, {:config, "eth0"}, state: @ipv4_state0)
    assert {:ok, _wlan0} = Informant.publish(Networking, {:config, "wlan0"}, state: @ipv4_state0)

    # A lookup of an exact term should return one item
    assert Informant.lookup(Networking, {:config, "wlan0"}) == [
      {{:config, "wlan0"}, @ipv4_state0}
    ]

    # A wildcard lookup should return both in no particular order
    # REVIEW this assumes order and test is too fragile
    assert Informant.lookup(Networking, {:config, :_}) == [
       {{:config, "eth0"}, @ipv4_state0}, {{:config, "wlan0"}, @ipv4_state0} ]

  end

  test "sources remove associated topics when they die" do

    Informant.start_link(DieTest)
    Informant.subscribe(DieTest, {:config, :_}) # wildcard subscribe

    refute_receive {:informant, DieTest, {:config, _}, {:join, _, :_}, _}

    _die_pid = spawn fn() ->
      {:ok, _eth0} = Informant.publish(DieTest, {:config, "eth0"}, state: @ipv4_state0)
      :timer.sleep(100)
    end

    assert_receive {:informant, DieTest, {:config, _}, {:join, _, :published}, _}
    #
    # Process.exit(die_pid, :quit)
    :timer.sleep(300)

    #assert_receive {:informant, DieTest, {:config, _}, {:join, _, :published}, _}

    # TODO implement this test properly
  end

end
