import javax.websocket.*;
import javax.websocket.server.ServerEndpoint;
import java.io.IOException;
import java.util.Set;
import java.util.concurrent.*;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.atomic.AtomicInteger;

@ServerEndpoint("/ws")
public class MyWebSocketServer {
    private static final Set<MyWebSocketServer> clients = new CopyOnWriteArraySet<>();
    private static final AtomicInteger clientCount = new AtomicInteger(0);
    private static final ConcurrentHashMap<String, Set<MyWebSocketServer>> rooms = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> roomText = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Lock> roomLocks = new ConcurrentHashMap<>();
    
    private Session session;
    private String clientName;
    private String currentRoom = null;

    @OnOpen
    public void onOpen(Session session) {
        this.session = session;
        clients.add(this);
        int count = clientCount.incrementAndGet();
        System.out.println("Client connected. Total clients: " + count);
    }

    @OnMessage
    public void onMessage(String message, Session session) {
        System.out.println("Received message: " + message);
        String[] parts = message.split("&");
        String messageType = parts[0].split("=")[1];

        if ("join".equals(messageType)) {
            this.clientName = parts[1].split("=")[1];  // Extract client name
            String roomName = parts[2].split("=")[1];
            joinRoom(roomName);
        } else if ("leave".equals(messageType)) {
            leaveRoom();
        } else if ("textUpdate".equals(messageType)) {
            String textMessage = parts[1].split("=")[1];
            updateRoomText(textMessage);
        } else if ("messageUpdate".equals(messageType)) {
            String textMessage = parts[1].split("=")[1];
            String formattedMessage = clientName + ": " + textMessage; // Attach client name
            broadcastToRoom(currentRoom, "type=messageUpdate&message=" + formattedMessage);
        }
    }

    @OnClose
    public void onClose(Session session) {
        leaveRoom();
        clients.remove(this);
        int count = clientCount.decrementAndGet();
        System.out.println("Client disconnected. Total clients: " + count);
    }

    private void joinRoom(String roomName) {
        this.currentRoom = roomName;

        roomLocks.putIfAbsent(roomName, new ReentrantLock());
        Lock lock = roomLocks.get(roomName);

        try {
            lock.lock();
            rooms.putIfAbsent(roomName, new CopyOnWriteArraySet<>());
            rooms.get(roomName).add(this);

            String welcomeMessage = clientName + " has joined the room.";
            broadcastToRoom(roomName, "type=join&message=" + welcomeMessage);

            if (roomText.containsKey(roomName)) {
                session.getBasicRemote().sendText("type=textUpdate&message=" + roomText.get(roomName));
            }
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            lock.unlock();
        }
    }

    private void leaveRoom() {
        if (currentRoom != null) {
            Lock lock = roomLocks.get(currentRoom);

            try {
                lock.lock();
                rooms.get(currentRoom).remove(this);
                if (rooms.get(currentRoom).isEmpty()) {
                    rooms.remove(currentRoom);
                    roomText.remove(currentRoom);
                    roomLocks.remove(currentRoom);
                }
                String leaveMessage = clientName + " has left the room.";
                broadcastToRoom(currentRoom, "type=leave&message=" + leaveMessage);
            } finally {
                lock.unlock();
            }
        }
    }

    private void updateRoomText(String textMessage) {
        if (currentRoom != null) {
            Lock lock = roomLocks.get(currentRoom);

            try {
                lock.lock();
                roomText.put(currentRoom, textMessage);
                broadcastToRoom(currentRoom, "type=textUpdate&message=" + textMessage);
            } finally {
                lock.unlock();
            }
        }
    }

    private void broadcastToRoom(String roomName, String message) {
        Set<MyWebSocketServer> roomClients = rooms.get(roomName);
        if (roomClients != null) {
            for (MyWebSocketServer client : roomClients) {
                try {
                    client.session.getBasicRemote().sendText(message);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }
}
