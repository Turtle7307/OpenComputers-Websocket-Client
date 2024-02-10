# OpenComputers-Websocket-Client

OpenComputers-Websocket-Client is a WebSocket client for OpenComputers that has been somewhat tested to work with the c# [WatsonWebsocket](https://github.com/jchristn/WatsonWebsocket) library.
<p/>

## What is supported?

- binary messages
- Text messages
- Continuous frames
- Masked messages

## What is not supported?

- [Transport Layer Security (TLS)](https://en.wikipedia.org/wiki/Transport_Layer_Security)

## Installation

1. download library by typing in a OpenComputers Computer:
    ```bash
    wget https://raw.githubusercontent.com/Turtle7307/OpenComputers-Websocket-Client/main/websocket.lua websocket.lua
    ```
2. Import library into your script:
    ```lua
    local websocket = require("websocket")
    ```

## Example

```lua
-- Get libs and init connection
local event = require("event")
local socket = require("websocket").connect("ws://www.example.com:9191", "ExampleSocket")

-- Register event listeners
event.listen("socketClosed", function(_, socketName, graceful, code, reason)
  if graceful then
    print("SocketClosed: [" .. socketName .. "] [graceful] [" .. code .. "] " .. reason)
  else
    print("SocketClosed: [" .. socketName .. "] [ungraceful] [" .. code .. "] " .. reason)
  end
end)
event.listen("socketOpen", function(_, socketName, socket)
  print("SocketOpened: [" .. socketName .. "] SocketOpen")
end)
event.listen("socketMessage", function(_, socketName, message, opcode)
  print("SocketMessage: [" .. socketName .. "] [" .. opcode .."] " .. message)
end)

-- Finish connecting
while true do
  local connected, err = socket:finishConnect()
  if connected then break end
  if err then return print('Failed to connect: ' .. err) end
  if event.pull(1, "interrupted") ~= nil then
    socket:close()
    return
  end
end
print("Connected to WebSocket server!")

-- Send message to Server
socket:send("Hello Server")

event.pull(10, "interrupted")

-- Close WebSocket
socket:close()
```

### Explanation of the example

1. Import the event library to later read the Open/Closing as well es the receiving of messages from the socket. We also need to import the websocket library to actually use it, and we directly call the connect function with our server address and the Name we want the socket to have. The function returns a Socket that has already begun to connect to the server.
    ```lua
    local event = require("event")
    local socket = require("websocket").connect("ws://www.example.com:9191", "ExampleSocket")
    ```

2. Next we register event listeners for the different events the socket sends. If we register them later we would potentially not catch some events that the socket sends.
    ```lua
    event.listen("socketClosed", function(_, socketName, graceful, code, reason)
      if graceful then
        print("SocketClosed: [" .. socketName .. "] [graceful] [" .. code .. "] " .. reason)
      else
        print("SocketClosed: [" .. socketName .. "] [ungraceful] [" .. code .. "] " .. reason)
      end
    end)
    event.listen("socketOpen", function(_, socketName, socket)
      print("SocketOpened: [" .. socketName .. "] SocketOpen")
    end)
    event.listen("socketMessage", function(_, socketName, message, opcode)
      print("SocketMessage: [" .. socketName .. "] [" .. opcode .."] " .. message)
    end)
    ```

3. After the event listeners we finish the connection to the Server by calling the finishConnect function multiple times until it returns true or errors. We as well need to check for an event to prevent OpenComputers from thinking that the code is in an infinite loop and at the same time we can check if the program was interrupted.
    ```lua
    while true do
      local connected, err = socket:finishConnect()
      if connected then break end
      if err then return print('Failed to connect: ' .. err) end
      if event.pull(1, "interrupted") ~= nil then
        socket:close()
        return
      end
    end
    print("Connected to WebSocket server!")
    ```

4. Next we can finally send a message to the Server and wait for 10 seconds until we close the socket. If in the 10 seconds a message is received the socket will send a socketMessage event which would then execute our registered event listener, which will print the message to the console.
    ```lua
    socket:send("Hello Server")
    event.pull(10, "interrupted")
    socket:close()
    ```