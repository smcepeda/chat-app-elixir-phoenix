defmodule ChatWeb.RoomLive do
  use ChatWeb, :live_view
  require Logger

  @impl true
  @spec mount(map, any, Phoenix.LiveView.Socket.t()) :: {:ok, any}
  def mount(%{"id" => room_id}, _session, socket) do
    topic = "room:" <> room_id
    username = MnemonicSlugs.generate_slug(1)
    <> "@simpli"
    if connected?(socket) do
      ChatWeb.Endpoint.subscribe(topic)
      ChatWeb.Presence.track(self(), topic, username, %{})
    end

    {:ok, assign(socket, room_id: room_id, topic: topic, username: username, message: "", messages: [], temporary_assigns: [messages: []])}
  end

  @impl true
  @spec handle_event(<<_::96, _::_*16>>, map, any) :: {:noreply, any}
  def handle_event("submit_message", %{"chat" => %{"message" => message}}, socket) do
    message = %{uuid: UUID.uuid4(), content: message, username: socket.assigns.username}
    ChatWeb.Endpoint.broadcast(socket.assigns.topic, "new-message", message)
    {:noreply, assign(socket, message: "")}
  end

  @impl true
  def handle_event("form_updated", %{"chat" => %{"message" => message}}, socket) do
    Logger.info(message: message)
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_info(%{event: "new-message", payload: message}, socket) do
    Logger.info(payload: message)
    {:noreply, assign(socket, messages: [message])}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    join_messages = joins |> Map.keys() |> Enum.map(fn username -> %{uuid: UUID.uuid4(), content: "#{username} joined", type: :system} end)

    leave_messages = leaves |> Map.keys() |> Enum.map(fn username -> %{uuid: UUID.uuid4(), content: "#{username} left", type: :system} end)

    user_list = ChatWeb.Presence.get_by_key(socket.assigns.topic, socket.assigns.username)
    Logger.info(user_list: user_list)
    {:noreply, assign(socket, messages: join_messages ++ leave_messages)}
  end

  def display_message(%{type: :system, uuid: uuid, content: content}) do
    ~E"""
    <p id="<%= uuid %>"><em><%= content %></em></p>

    """
  end

  def display_message(%{uuid: uuid, content: content, username: username}) do
  ~E"""
    <p id="<%= uuid %>"><strong><%= username %>:</strong> <%= content %></p>
    """
  end

end
