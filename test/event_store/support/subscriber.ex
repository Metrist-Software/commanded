defmodule Commanded.EventStore.Subscriber do
  use GenServer

  alias Commanded.EventStore
  alias Commanded.EventStore.Subscriber

  defmodule State do
    defstruct [:application, :owner, :subscription, received_events: [], subscribed?: false]
  end

  alias Subscriber.State

  def start_link(application, owner) do
    state = %State{application: application, owner: owner}

    GenServer.start_link(__MODULE__, state)
  end

  def init(%State{} = state) do
    %State{application: application} = state

    {:ok, subscription} =
      EventStore.subscribe_to(application, :all, "subscriber", self(), :origin)

    {:ok, %State{state | subscription: subscription}}
  end

  def subscribed?(subscriber),
    do: GenServer.call(subscriber, :subscribed?)

  def received_events(subscriber),
    do: GenServer.call(subscriber, :received_events)

  def handle_call(:subscribed?, _from, %State{} = state) do
    %State{subscribed?: subscribed?} = state

    {:reply, subscribed?, state}
  end

  def handle_call(:received_events, _from, %State{} = state) do
    %State{received_events: received_events} = state

    {:reply, received_events, state}
  end

  def handle_info({:subscribed, subscription}, %State{subscription: subscription} = state) do
    %State{owner: owner} = state

    send(owner, {:subscribed, subscription})

    {:noreply, %State{state | subscribed?: true}}
  end

  def handle_info({:events, events}, %State{} = state) do
    %State{
      application: application,
      owner: owner,
      received_events: received_events,
      subscription: subscription
    } = state

    send(owner, {:events, events})

    state = %State{state | received_events: received_events ++ events}

    EventStore.ack_event(application, subscription, List.last(events))

    {:noreply, state}
  end
end
