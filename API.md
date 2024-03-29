# API

## Imported table

### Functions

* `connect(url: string, [socketName: string], [websocket_protocol: string|table]): socket_connection` Creates a new connection and starts to connect to the server.
    * `url`: The url the websocket should connect to.
    * `socketName`: The name for the websocket that is returned by the events to identify the origin of the event in case multiple connections are used simultaneously.
    * `websocket_protocol`: The protocols the websocket should use to communicate.
    * `socket_connection: table`: A new table that handles the socket connection.

### Fields

The listed fields should ***not*** be modified!
* `Opcodes: table` A table that has all the possible Frame Types.

## Socket Connection Table

### Functions

* `socket:connect([url: string], [websocket_protocol: string])` Begin connecting to the server.
    * `url`: The url the socket should connect to. (If left empty it will try to reconnect)
    * `websocket_protocol`: The protocols the websocket should use to communicate.
* `socket:finishConnect(): success, error` Finish connecting to the server. This function needs to be called multiple times as it is a coroutine internally.
    * `success: boolean`: If the socket was able to connect successfully.
    * `error: string`: The error that happened while connecting.
* `socket:send(message: string, [opcode: number])` Send a message to the connected server.
    * `message`: The message to send to the server.
    * `opcode`: The type of message to send.
* `socket:close([code: number], [reason: string], [timeout: number])` Closes the connection to the server.
    * `code`: The code for why the connection is being closed.
    * `reason`: The reason why the connection is being closed.
    * `timeout`: The time the socket waits for the server to confirm the closing of the connection.

### Events

* `socketOpen`: The server established a connection to the server.
    * `socketName: string`: The name of the socket.
    * `socket: table`: The socket.
* `socketMessage`: A message was received.
    * `socketName: string`: The name of the socket.
    * `message: string`: The message received from the server.
    * `opcode: number`: The type of message.
* `socketClosed`: The connection to the server was closed.
    * `socketName: string`: The name of the socket.
    * `graceful: boolean`: If the connection wasn't suddenly destroyed.
    * `code: number`: The code for why the connection was terminated.
    * `reason: string`: The reason for why the connection was terminated.

### Fields

Any fields not listed here should ***not*** be modified!
* `Opcodes: table` A table that has all the possible Frame Types. ***Do not Modify!***
* `state: string` The current state of the socket. ***Do not Modify!***
* `name: string` The name of the socket.
* `messageReadTimeout: number` The time in seconds the read Thread waits to read 1000 bytes of data to process. The smallest allowed timeout is 0.05. [default: 0.2]

## Opcodes

The type of frames possible to send and receive over the socket. Any types not listed are internal and should ***not*** be used.
* `TEXT`
* `BINARY`
* `PING`
* `PONG`