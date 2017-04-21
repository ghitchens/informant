defmodule InformantTest do
  use ExUnit.Case
  doctest Informant

  test "update and get work with one item" do
    {:ok, _} = Informant.start_link()
    assert Informant.get(Nerves.Networking, {:net, "eth0"}, :ipv4_address) == nil
    assert Informant.find({:net, "eth0", :ipv4_address}) == []

    assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.1") == :ok
    assert Informant.get({:net, "eth0", :ipv4_address}) == "127.0.0.1"
    assert Informant.find({:net, "eth0", :ipv4_address}) == [{{:net, "eth0", :ipv4_address}, "127.0.0.1"}]
  end

  test "update and get work with multiple items" do
    {:ok, _} = Informant.start_link()
    assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.1") == :ok
    assert Informant.update({:net, "wlan0", :ipv4_address}, "127.0.0.1") == :ok
    assert Informant.update({:net, "wlan0", :something_else}, 4) == :ok

    # Get all IPv4 addresses
    assert Informant.find({:net, :_, :ipv4_address}) ==
      [{{:net, "eth0", :ipv4_address}, "127.0.0.1"}, {{:net, "wlan0", :ipv4_address}, "127.0.0.1"}]
  end

  test "notification when register" do
    {:ok, _} = Informant.start_link()

    # Set the IP address
    assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.1") == :ok

    # Someone comes in a registers after the interface is configured
    # to get all eth0 IP address changes
    assert Informant.register({:net, "eth0", :ipv4_address})

    # Make sure that we get a notification
    assert_receive [{{:net, "eth0", :ipv4_address}, "127.0.0.1"}]
  end

  test "notification on update" do
    {:ok, _} = Informant.start_link()

    # Register before the IP address is set
    assert Informant.register({:net, "eth0", :ipv4_address})

    # Set the IP address for something uninteresting
    assert Informant.update({:net, "wlan0", :ipv4_address}, "127.0.0.3") == :ok

    # Set the IP address
    assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.2") == :ok

    # Make sure that we get a notification
    assert_receive [{{:net, "eth0", :ipv4_address}, "127.0.0.2"}]
  end

  test "wildcard notifications" do
    {:ok, _} = Informant.start_link()

    # Register for all IP address changes
    assert Informant.register({:net, :_, :ipv4_address})

    # Check that we get updates for wlan0
    assert Informant.update({:net, "wlan0", :ipv4_address}, "127.0.0.4") == :ok
    assert_receive [{{:net, "wlan0", :ipv4_address}, "127.0.0.4"}]

    # Check that we get updates for eth0
    assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.5") == :ok
    assert_receive [{{:net, "eth0", :ipv4_address}, "127.0.0.5"}]
  end

  test "batch wildcard notification on init" do
    {:ok, _} = Informant.start_link()

    # IP address notifications go out before register is called
    assert Informant.update({:net, "wlan0", :ipv4_address}, "127.0.0.6") == :ok
    assert Informant.update({:net, "eth0", :ipv4_address}, "127.0.0.7") == :ok

    # Register for all IP address changes
    assert Informant.register({:net, :_, :ipv4_address})

    # Get two notifications (order not guaranteed except for this test)
    assert_receive [{{:net, "eth0", :ipv4_address}, "127.0.0.7"},
                    {{:net, "wlan0", :ipv4_address}, "127.0.0.6"}]
  end

end
