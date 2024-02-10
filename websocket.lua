--MIT License
--
--Copyright (c) 2024 Turtle7307
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.

local component = require("component")
local thread = require("thread")
local buffer = require("buffer")
local event = require("event")
local bit = require("bit32")

local bits = function(...)
    local n = 0
    for _,bitn in pairs{...} do
        n = n + 2^bitn
    end
    return n
end

local bit_7 = bits(7)
local bit_0_3 = bits(0,1,2,3)
local bit_0_6 = bits(0,1,2,3,4,5,6)

local read_n_bytes = function(str, pos, n)
    pos = pos or 1
    return pos+n, string.byte(str, pos, pos + n - 1)
end

local read_int8 = function(str, pos)
    return read_n_bytes(str, pos, 1)
end

local read_int16 = function(str, pos)
    local new_pos,a,b = read_n_bytes(str, pos, 2)
    return new_pos, bit.lshift(a, 8) + b
end

local read_int32 = function(str, pos)
    local new_pos,a,b,c,d = read_n_bytes(str, pos, 4)
    return new_pos,
    bit.lshift(a, 24) +
    bit.lshift(b, 16) +
    bit.lshift(c, 8 ) +
    d
end

local write_int8 = string.char

local write_int16 = function(v)
    return string.char(bit.rshift(v, 8), bit.band(v, 0xFF))
end

local write_int32 = function(v)
    return string.char(
        bit.band(bit.rshift(v, 24), 0xFF),
        bit.band(bit.rshift(v, 16), 0xFF),
        bit.band(bit.rshift(v,  8), 0xFF),
        bit.band(v, 0xFF)
    )
end

local base64_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function base64_encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return base64_chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local sha1 = function(msg)
    local h0 = 0x67452301
    local h1 = 0xEFCDAB89
    local h2 = 0x98BADCFE
    local h3 = 0x10325476
    local h4 = 0xC3D2E1F0

    local bits = #msg * 8
    -- append b10000000
    msg = msg .. string.char(0x80)

    -- 64 bit length will be appended
    local bytes = #msg + 8

    -- 512 bit append stuff
    local fill_bytes = 64 - (bytes % 64)
    if fill_bytes ~= 64 then
        msg = msg .. string.rep(string.char(0),fill_bytes)
    end

    -- append 64 big endian length
    local high = math.floor(bits/2^32)
    local low = bits - high*2^32
    msg = msg .. write_int32(high) .. write_int32(low)

    assert(#msg % 64 == 0,#msg % 64)

    for j=1,#msg,64 do
        local chunk = msg:sub(j,j+63)
        assert(#chunk==64,#chunk)
        local words = {}
        local next = 1
        local word
        repeat
            next,word = read_int32(chunk, next)
            table.insert(words, word)
        until next > 64
        assert(#words==16)
        for i=17,80 do
            words[i] = bit.bxor(words[i-3],words[i-8],words[i-14],words[i-16])
            words[i] = bit.lrotate(words[i],1)
        end
        local a = h0
        local b = h1
        local c = h2
        local d = h3
        local e = h4

        for i=1,80 do
        local k,f
        if i > 0 and i < 21 then
            f = bit.bor(bit.band(b,c),bit.band(bit.bnot(b),d))
            k = 0x5A827999
        elseif i > 20 and i < 41 then
            f = bit.bxor(b,c,d)
            k = 0x6ED9EBA1
        elseif i > 40 and i < 61 then
            f = bit.bor(bit.band(b,c),bit.band(b,d),bit.band(c,d))
            k = 0x8F1BBCDC
        elseif i > 60 and i < 81 then
            f = bit.bxor(b,c,d)
            k = 0xCA62C1D6
        end

        local temp = bit.lrotate(a,5) + f + e + k + words[i]
        e = d
        d = c
        c = bit.lrotate(b,30)
        b = a
        a = temp
        end

        h0 = h0 + a
        h1 = h1 + b
        h2 = h2 + c
        h3 = h3 + d
        h4 = h4 + e

    end

    -- necessary on sizeof(int) == 32 machines
    h0 = bit.band(h0,0xffffffff)
    h1 = bit.band(h1,0xffffffff)
    h2 = bit.band(h2,0xffffffff)
    h3 = bit.band(h3,0xffffffff)
    h4 = bit.band(h4,0xffffffff)

    return write_int32(h0) .. write_int32(h1) .. write_int32(h2) .. write_int32(h3) .. write_int32(h4)
end

local generate_key = function()
    local r1 = math.random(0,0xfffffff)
    local r2 = math.random(0,0xfffffff)
    local r3 = math.random(0,0xfffffff)
    local r4 = math.random(0,0xfffffff)
    local key = write_int32(r1)..write_int32(r2)..write_int32(r3)..write_int32(r4)
    assert(#key==16,#key)
    return base64_encode(key)
end

local parse_url = function(url)
    local protocol, address, uri = url:match('^(%w+)://([^/]+)(.*)$')
    if not protocol then error('Invalid URL:' .. url) end
    protocol = protocol:lower()
    local host, port = address:match("^(.+):(%d+)$")
    if not host then
        host = address
        port = 80
    end
    if not uri or uri == '' then uri = '/' end
    return protocol, host, tonumber(port), uri
end

local upgrade_request = function(req)
    local format = string.format
    local lines = {
        format('GET %s HTTP/1.1',req.uri or ''),
        format('Host: %s',req.host),
        'Upgrade: websocket',
        'Connection: Upgrade',
        format('Sec-WebSocket-Key: %s',req.key),
        format('Sec-WebSocket-Protocol: %s',table.concat(req.protocols,', ')),
        'Sec-WebSocket-Version: 13',
    }
    if req.origin then
        table.insert(lines,string.format('Origin: %s',req.origin))
    end
    if req.port and req.port ~= 80 then
        lines[2] = format('Host: %s:%d',req.host,req.port)
    end
    table.insert(lines,'\r\n')
    return table.concat(lines,'\r\n')
end

local http_headers = function(request)
    local headers = {}
    if not request:match('.*HTTP/1%.1') then
        return headers
    end
    request = request:match('[^\r\n]+\r\n(.*)')
    local empty_line
    for line in request:gmatch('[^\r\n]*\r\n') do
        local name,val = line:match('([^%s]+)%s*:%s*([^\r\n]+)')
        if name and val then
            name = name:lower()
            if not name:match('sec%-websocket') then
                val = val:lower()
            end
            if not headers[name] then
                headers[name] = val
            else
                headers[name] = headers[name]..','..val
            end
        elseif line == '\r\n' then
            empty_line = true
        else
            assert(false,line..'('..#line..')')
        end
    end
    return headers,request:match('\r\n\r\n(.*)')
end

local guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
local sec_websocket_accept = function(sec_websocket_key)
    local a = sec_websocket_key .. guid
    local sha1 = sha1(a)
    assert((#sha1 % 2) == 0)
    return base64_encode(sha1)
end

local read = function(socket, n)
    local yieldable = coroutine.isyieldable()
    if socket.buffer == nil then socket.buffer = "" end

    while true do
        if n == nil then
            local buf = socket.buffer
            socket.buffer = ""
            return buf
        elseif #socket.buffer >= n then
            local data = string.sub(socket.buffer, 1, n)
            socket.buffer = string.sub(socket.buffer, n + 1)
            return data
        end

        local chunk, err = socket.tcpSocket.read()

        if chunk == nil then
        socket:close()
            return nil, err
        end

        socket.buffer = socket.buffer .. chunk

        if yieldable and chunk == "" then
            coroutine.yield()
            if socket.state == "CLOSED" or socket.state == "CLOSING" then
                return nil, "Socket closed while reading data"
            end
        end
    end
end

local performHandshake = function(socket)
    socket.key = generate_key()
    local request = upgrade_request({
        key = socket.key,
        host = socket.host,
        port = socket.port,
        protocols = socket.ws_protocols,
        origin = nil,
        uri = socket.uri
    })

    local written, err = socket.tcpSocket.write(request)
    if written == nil then return false, err end

    local handshakeResponse = ""
    while handshakeResponse:sub(-4) ~= "\r\n\r\n" do
        local data, err = read(socket, 1)
        if data == nil then return false, err end

        handshakeResponse = handshakeResponse .. data
    end

    local headers = http_headers(handshakeResponse)
    local expected_accept = sec_websocket_accept(socket.key)
    if headers['sec-websocket-accept'] ~= expected_accept then
        socket.state = 'CLOSED'
        error('accept failed', 2)
        return
    end

    return true
end

local close = function(socket, graceful_close, code, reason)
    socket.tcpSocket.close()
    socket.buffer = ""
    socket.uri, socket.port, socket.host, socket.key, socket.connectionError, socket.tcpSocket, socket.closeTimer = nil
    socket.state = "CLOSED"
    event.push("socketClosed", socket.name, graceful_close, code, reason or "")
end

local Opcodes = {
  CONTINUATION = 0,
  TEXT = 1,
  BINARY = 2,
  CLOSE = 8,
  PING = 9,
  PONG = 10
}

local encode_frame_close = function(code,reason)
  if code then
    local data = write_int16(code)
    if reason then
      data = data..tostring(reason)
    end
    return data
  end
  return ""
end

local decode_frame_close = function(data)
  local _,code,reason
  if data then
    if #data > 1 then
      _,code = read_int16(data,1)
    end
    if #data > 2 then
      reason = data:sub(3)
    end
  end
  return code,reason
end

local xor_mask = function(encoded,mask,payload)
    local transformed,transformed_arr = {},{}
    -- xor chunk-wise to prevent stack overflow.
    -- sbyte and schar multiple in/out values
    -- which require stack
    for p=1,payload,2000 do
        local last = math.min(p+1999,payload)
        local original = {string.byte(encoded,p,last)}
        for i=1,#original do
            local j = (i-1) % 4 + 1
            transformed[i] = bit.bxor(original[i],mask[j])
        end
        local xored = string.char(table.unpack(transformed,1,#original))
        table.insert(transformed_arr,xored)
    end
    return table.concat(transformed_arr)
end

local encode_header_small = function(header, payload)
    return string.char(header, payload)
end

local encode_header_medium = function(header, payload, len)
    return string.char(header, payload, bit.band(bit.rshift(len, 8), 0xFF), bit.band(len, 0xFF))
end

local encode_header_big = function(header, payload, high, low)
    return string.char(header, payload) .. write_int32(high) .. write_int32(low)
end

local encode_frame = function(data,opcode,masked,fin)
    local header = opcode or 1-- TEXT is default opcode
    if fin == nil or fin == true then
        header = bit.bor(header,bit_7)
    end
    local payload = 0
    if masked then
        payload = bit.bor(payload,bit_7)
    end
    local len = #data
    local chunks = {}
    if len < 126 then
        payload = bit.bor(payload,len)
        table.insert(chunks,encode_header_small(header,payload))
    elseif len <= 0xffff then
        payload = bit.bor(payload,126)
        table.insert(chunks,encode_header_medium(header,payload,len))
    elseif len < 2^53 then
        local high = math.floor(len/2^32)
        local low = len - high*2^32
        payload = bit.bor(payload,127)
        table.insert(chunks,encode_header_big(header,payload,high,low))
    end
    if not masked then
        table.insert(chunks,data)
    else
        local m1 = math.random(0,0xff)
        local m2 = math.random(0,0xff)
        local m3 = math.random(0,0xff)
        local m4 = math.random(0,0xff)
        local mask = {m1,m2,m3,m4}
        table.insert(chunks,write_int8(m1,m2,m3,m4))
        table.insert(chunks,xor_mask(data,mask,#data))
    end
    return table.concat(chunks)
end

local decode_frame = function(encoded)
    local encoded_bak = encoded
    if #encoded < 2 then
        return nil,2-#encoded
    end
    local pos,header,payload
    pos,header = read_int8(encoded,1)
    pos,payload = read_int8(encoded,pos)
    local high,low
    encoded = string.sub(encoded,pos)
    local bytes = 2
    local fin = bit.band(header,bit_7) > 0
    local opcode =bit. band(header,bit_0_3)
    local mask = bit.band(payload,bit_7) > 0
    payload = bit.band(payload,bit_0_6)
    if payload > 125 then
        if payload == 126 then
            if #encoded < 2 then
                return nil,2-#encoded
            end
            pos,payload = read_int16(encoded,1)
        elseif payload == 127 then
            if #encoded < 8 then
                return nil,8-#encoded
            end
            pos,high = read_int32(encoded,1)
            pos,low = read_int32(encoded,pos)
            payload = high*2^32 + low
            if payload < 0xffff or payload > 2^53 then
                assert(false,'INVALID PAYLOAD '..payload)
            end
        else
            assert(false,'INVALID PAYLOAD '..payload)
        end
        encoded = string.sub(encoded,pos)
        bytes = bytes + pos - 1
    end
    local decoded
    if mask then
        local bytes_short = payload + 4 - #encoded
        if bytes_short > 0 then
            return nil,bytes_short
        end
        local m1,m2,m3,m4
        pos,m1 = read_int8(encoded,1)
        pos,m2 = read_int8(encoded,pos)
        pos,m3 = read_int8(encoded,pos)
        pos,m4 = read_int8(encoded,pos)
        encoded = string.sub(encoded,pos)
        local mask = {
            m1,m2,m3,m4
        }
        decoded = xor_mask(encoded,mask,payload)
        bytes = bytes + 4 + payload
    else
        local bytes_short = payload - #encoded
        if bytes_short > 0 then
            return nil,bytes_short
        end
        if #encoded > payload then
            decoded = string.sub(encoded,1,payload)
        else
            decoded = encoded
        end
        bytes = bytes + payload
    end
    return decoded,fin,opcode,encoded_bak:sub(bytes+1),mask
end

local readMessages = function(socket)
    socketBuffer = buffer.new("r", {
        read = function(_, readBytes)
            local chunk, err = socket.tcpSocket.read(readBytes)
            if chunk == "" then
                return nil
            else
                return chunk
            end
        end,
        close = function(_)
            return false, "operation not supported"
        end,
        seek = function(_, whence, offset)
            return false, "operation not supported"
        end,
        write = function(_, toWrite)
            return false, "operation not supported"
        end
    })
    local stop = false
    local currentTimeout = 0
    local first_opcode = nil
    local frames = {}

    while not stop do
        if currentTimeout ~= socket.messageReadTimeout and socket.messageReadTimeout ~= nil and type(socket.messageReadTimeout) == "number" then
            if socket.messageReadTimeout < 0.05 then
                socket.messageReadTimeout = 0.05
            end
            socketBuffer:setTimeout(socket.messageReadTimeout)
        end
        local encoded, err = socketBuffer:read(1000)

        if encoded ~= nil then
            if socket.buffer ~= "" then
                encoded = socket.buffer .. encoded
                last = ""
            else
                encoded = encoded
            end

            repeat
                local decoded, fin, opcode, rest = decode_frame(encoded)
                if decoded then
                    if not first_opcode then
                        first_opcode = opcode
                    end
                    table.insert(frames, decoded)
                    encoded = rest
                    if fin == true then
                        local message = table.concat(frames)
                        local opcode = first_opcode
                        frames = {}
                        first_opcode = nil

                        if opcode == Opcodes.TEXT or opcode == Opcodes.BINARY then
                            event.push("socketMessage", socket.name, message, opcode)
                        elseif opcode == Opcodes.CLOSE then
                            if socket.state ~= "CLOSING" then
                                socket.state = "CLOSING"
                                local code, reason = decode_frame_close(message)
                                local encoded = encode_frame_close(code)
                                encoded = encode_frame(encoded, Opcodes.CLOSE, true)
                                socket.tcpSocket.write(encoded)
                                stop = true
                                close(socket, true, code or 1005, reason)
                            else
                                stop = true
                                close(socket, true, 1005, "")
                                event.push("InternalWebsocketCloseFinished")
                            end
                        end
                    end
                end
            until not decoded
        end

        if event.pull(0, "interrputed") == "interrputed" then
            socket.closeTimer = event.timer(1, function()
                socket:close(1006, "")
            end)
        end
    end
end

local connectionCoroutine = function(socket)
    socket.state = "CONNECTING"

    local yieldable = coroutine.isyieldable()
    local connected = false
    repeat
        local c, connectionError = socket.tcpSocket.finishConnect()
        connected = c
        if connectionError then return false, connectionError end
        if yieldable then coroutine.yield() end
        if socket.state == "CLOSED" or socket.state == "CLOSING" then
            return false, "Socket closed while connecting"
        end
    until connected

    local success, err = performHandshake(socket)
    if success == true then
        socket.state = "OPEN"
        socket.messageReadThread = thread.create(readMessages, socket)
        event.push("socketOpen", socket.name, socket)
    end
    return success, err
end

local createSocket = function(name)
    local socket = {
        Opcodes = Opcodes,
        state = "CLOSED",
        buffer = "",
        name = name or "",
        messageReadTimeout = 0.2,
        messageReadThread = nil,
        closeTimer = nil,
        tcpSocket = nil,
        connectionCoroutine = nil,
        connectionError = nil,
        key = nil,
        host = nil,
        port = nil,
        ws_protocols = nil,
        uri = nil,
        url = nil,
    }

    socket.connect = function(this, url, ws_protocol)
        if this.state ~= "CLOSED" then
            error("WebSocket is not closed", 2)
        end

        -- allow for reconnecting
        url = url or this.url
        ws_protocol = ws_protocol or this.ws_protocols

        -- check if components and parameters are valid
        assert(type(url) == "string", "the address needs to be a string")
        if not component.isAvailable("internet") then
            error("no primary internet card found", 2)
        end
        assert(component.internet.isTcpEnabled(), "TCP must be enabled to use WebSocket")
        local protocol, host, port, uri = parse_url(url)
        if protocol ~= "ws" then
            error("only ws protocol is supported", 2)
        end

        -- check  protocol
        ws_protocol =  ws_protocol or "chat"
        local ws_protocols_tbl = {''}
        if type(ws_protocol) == 'string' then
            ws_protocols_tbl = {ws_protocol}
        elseif type(ws_protocol) == 'table' then
            ws_protocols_tbl = ws_protocol
        end

        -- saving data for later
        this.url = url
        this.host = host
        this.port = port
        this.uri = uri
        this.ws_protocols = ws_protocols_tbl

        -- connect
        this.state = "CONNECTING"
        this.tcpSocket = component.internet.connect(protocol .. "://" .. host, port)
        this.connectionCoroutine = coroutine.create(function() return connectionCoroutine(this) end)
    end

    socket.finishConnect = function(this)
        if this.state == "OPEN" then return true end
        if this.connectionError then return nil, this.connectionError end
        if this.state ~= "CONNECTING" then return nil, "There is no connection to finish" end
        if coroutine.status(this.connectionCoroutine) ~= 'dead' then
            local success, connected = coroutine.resume(this.connectionCoroutine)
            if not success and connected then
                this.connectionError = connected
                return nil, connected
            end
            if type(connected) == 'boolean' then
                return connected
            end
        end
    end

    socket.close = function(this, code, reason, timeout)
        if this.state == "CONNECTING" then
            this.state = "CLOSING"
            while coroutine.status(this.connectionCoroutine) ~= 'dead' do
                local success, connected = coroutine.resume(this.connectionCoroutine)
                if not success and connected then
                    this.connectionError = connected
                end
            end
            close(this, false, 1006, "")
        elseif this.state == "OPEN" then
            this.state = "CLOSING"
            local encoded = encode_frame_close(code or 1000, reason)
            encoded = encode_frame(encoded, Opcodes.CLOSE, true)
            this.tcpSocket.write(encoded)
            if event.pull(timeout or 3, "InternalWebsocketCloseFinished") == nil then
                close(this, false, 1006, "timeout")
            end
        end
    end

    socket.send = function(this, message, opcode)
        assert(state ~= "OPEN", "The socket is not open!")
        local encoded = encode_frame(message, opcode or Opcodes.TEXT, true)
        this.tcpSocket.write(encoded)
    end

    return socket
end

return {
    connect = function(url, name, ws_protocol)
        local socket = createSocket(name)
        socket:connect(url, ws_protocol)
        return socket
    end,
    Opcodes = Opcodes,
}
