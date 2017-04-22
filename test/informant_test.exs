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


  #   }, :ipv4_address) == nil
  #   assert Informant.find({:net, "eth0", :ipv4_address}) == []
  #
  #   assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.1") == :ok
  #   assert Informant.get({:net, "eth0", :ipv4_address}) == "127.0.0.1"
  #   assert Informant.find({:net, "eth0", :ipv4_address}) == [{{:net, "eth0", :ipv4_address}, "127.0.0.1"}]
  # end
  #
  # test "update and get work with multiple items" do
  #   {:ok, _} = Informant.start_link()
  #   assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.1") == :ok
  #   assert Informant.update({:net, "wlan0", :ipv4_address}, "127.0.0.1") == :ok
  #   assert Informant.update({:net, "wlan0", :something_else}, 4) == :ok
  #
  #   # Get all IPv4 addresses
  #   assert Informant.find({:net, :_, :ipv4_address}) ==
  #     [{{:net, "eth0", :ipv4_address}, "127.0.0.1"}, {{:net, "wlan0", :ipv4_address}, "127.0.0.1"}]
  # end
  #
  # test "notification when register" do
  #   {:ok, _} = Informant.start_link()
  #
  #   # Set the IP address
  #   assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.1") == :ok
  #
  #   # Someone comes in a registers after the interface is configured
  #   # to get all eth0 IP address changes
  #   assert Informant.register({:net, "eth0", :ipv4_address})
  #
  #   # Make sure that we get a notification
  #   assert_receive [{{:net, "eth0", :ipv4_address}, "127.0.0.1"}]
  # end

  # test "wildcard notifications" do
  #   {:ok, _} = Informant.start_link()
  #
  #   # Register for all IP address changes
  #   assert Informant.register({:net, :_, :ipv4_address})
  #
  #   # Check that we get updates for wlan0
  #   assert Informant.update({:net, "wlan0", :ipv4_address}, "127.0.0.4") == :ok
  #   assert_receive [{{:net, "wlan0", :ipv4_address}, "127.0.0.4"}]
  #
  #   # Check that we get updates for eth0
  #   assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.5") == :ok
  #   assert_receive [{{:net, "eth0", :ipv4_address}, "127.0.0.5"}]
  # end
  #
  # test "batch wildcard notification on init" do
  #   {:ok, _} = Informant.start_link()
  #
  #   # IP address notifications go out before register is called
  #   assert Informant.update({:net, "wlan0", :ipv4_address}, "127.0.0.6") == :ok
  #   assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.7") == :ok
  #
  #   # Register for all IP address changes
  #   assert Informant.register({:net, :_, :ipv4_address})
  #
  #   # Get two notifications (order not guaranteed except for this test)
  #   assert_receive [{{:net, "eth0", :ipv4_address}, "127.0.0.7"},
  #                   {{:net, "wlan0", :ipv4_address}, "127.0.0.6"}]
  # end

end
