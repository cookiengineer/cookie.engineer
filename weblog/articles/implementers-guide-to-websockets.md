===
- date: 2019-01-18
- name: Implementer's Guide to WebSockets
- tags: web socket, network, node.js
- type: software, legacy
===

Today I implemented WebSocket support for [Stealth](https://github.com/cookiengineer/stealth).

But, I soon came to realize that when implementing WebSockets from
scratch that there is no go-to-and-know-everything resource
available on the internet.

Also, reading the RFC is kinda tedious, so I'm trying my best to
have enough code demos available for clarifications. This guide
tries to cover everything when it comes to the current WS13
network protocol, including reserved frames and how to support
them in future.

Most people will most likely use socket.io, but from my personal
view I wouldn't recommend it. In my use cases I use WebSockets
peer-to-peer (yes, you can, despite everybody else claiming no),
and the whole dependency tree of socket.io is rather redundant
than performant.

For the implementation we're going to build in this article,
we only need plain node.js and its `net` core stack. The
implementation will be peer-to-peer, which means it can be used
for both the client-side and server-side whereas both sides
are implemented in node.js for the sake of simplicity.


## Introduction

First off, you have to know that the `WS13` protocol is specified as
[RFC6455](https://tools.ietf.org/html/rfc6455)
and that there were a couple of legacy versions of Web Browsers around
for a while that implemented the websocket protocol in a buggy manner.

This is not the case anymore and I will completely ignore your shitty
Safari from the dark ages here (it's 2019, not 2011).

The Web-Socket Protocol is a web protocol that uses HTTP's `Upgrade`
mechanism in order to upgrade a connection. That means the first request
to the server is actually an HTTP request with the `Connection: Upgrade`
and `Upgrade: websocket` headers.

If the server has a specialized service-oriented architecture that
needs more than just websocket data frames in order to work, it is
good to implement it as a so-called sub protocol.

These subprotocols can be used in the Web Browser, too.

```javascript
// Browser Example
let socket = new WebSocket('ws://localhost:12345', [
	'me-want-cookies' // Sub-Protocol
]);
let data   = JSON.stringify({ foo: 'bar' });
let blob   = new Uint8Array(8);

socket.send(data); // Text Frame
socket.send(blob); // Binary Frame
```


## Web-Socket Server

The demo will be implemented using modern node.js. The server creation
has to be done with the `net.Server()` interface, as the data that
we need to access is `raw TCP data`, in order to have support for
everything binary.

It is important that the TCP connection is modified to fit our needs
in order to never timeout. The WS13 protocol uses a `Ping Frame` and
a `Pong Frame` which we have to manage ourselves, so we need to tell
the TCP networking stack that by setting `socket.allowHalfOpen` to `true`
and by calling `socket.setTimeout(0)` and `socket.setKeepAlive(true, 0)`.

As node.js runs `libuv` in the background, which is of asynchronous
nature, we also have to make sure that everything gets send as soon
as possible by calling `socket.setNoDelay(true)`.

```javascript
// server.mjs
import net from 'net';

import { WS } from './WS.mjs';


// Chapter: Opening Handshake
const _parse_opening_handshake = function(buffer) {
	let headers = {};
	return headers;
};

let server = new net.Server({
	allowHalfOpen:  true,
	pauseOnConnect: true
});

server.on('connection', socket => {

	socket.on('data', buffer => {

		let headers = _parse_opening_handshake(buffer);
		if (
			headers['connection'] === 'Upgrade'
			&& headers['upgrade'] === 'websocket'
			&& headers['sec-websocket-protocol'] === 'me-want-cookies'
		) {

			WS.upgrade(socket, headers, result => {

				if (result === true) {

					console.log('WS.upgrade() successful.');

					socket.allowHalfOpen = true;
					socket.setTimeout(0);
					socket.setNoDelay(true);
					socket.setKeepAlive(true, 0);

					socket.removeAllListeners('timeout');
					socket.removeAllListeners('data');

					socket.on('data', buffer => {

						WS.receive(socket, buffer, request => {
							console.log('Received request ', request);
						});

					});

				} else {

					console.error('WS.upgrade() unsuccessful.');
					console.error('Sorry, no HTTP allowed either, yo');

					socket.end();

				}

			});

		} else {

			console.error('Sorry, no TCP allowed, yo');

			socket.end();

		}

	});

	socket.on('error', _ => {});
	socket.on('close', _ => {});
	socket.on('timeout', _ => socket.close());

	socket.resume();

});

server.on('error', _ => server.close());
server.on('close', _ => (server = null));

server.listen(12345, null);
```

## Opening Handshake

The initial request that is done via HTTP is conform to `HTTP/1.1`,
so it is very easy to parse and the payload is encoded in `utf8`
and not `binary`, which eases up the parsing process.

The headers are - as every network byte ordered data - separated
by `\r\n` after each line, which means it's best to simply parse
line-by-line and just trim everything off to have margin for
malformed but recoverable handshakes.

```text
GET / HTTP/1.1
Host: example.cookie.engineer
Upgrade: websocket
Connection: Upgrade
Origin: http://localhost:12345
Sec-WebSocket-Key: bm9tbm9tCg==
Sec-WebSocket-Protocol: me-want-cookies
Sec-WebSocket-Version: 13
```

The header parsing mechanism for `HTTP/1.1` is quite easy,
as it's just utf8 encoded data that has a trailing `\r\n\r\n`
following its headers section.

Fragmented frames always have this, but you never know what
kind of script kiddie is challenging your server - so it's
good to have a failsafe parsing mechanism in place.

```javascript
// server.mjs

const _parse_opening_handshake = function(buffer) {

	let headers = {};

	let req = buffer.toString('utf8');
	let raw = req.split('\n').map(line => line.trim());

	if (raw[0].includes('HTTP/1.1')) {

		raw.slice(1).filter(line => line.trim() !== '').forEach(line => {

			let key = line.split(':')[0].trim().toLowerCase();
			let val = line.split(':').slice(1).join(':').trim();

			headers[key] = val;

		});

	}

	return headers;

};
```


## Connection Upgrade

After the initial Opening Handshake request, it's expected to send
the handshake verification back to the client.

The handshake response contains the `Sec-WebSocket-Accept` header
and the `Upgrade: WebSocket` and `Connection: Upgrade` as well.

Additionally, it is good to let the client know which protocol
we are expecting (so that mismatches can be handled automatically)
by sending the `Sec-WebSocket-Protocol: me-want-cookies` and
the `Sec-WebSocket-Version: 13` headers.

Note that the `nonce` salt for the reply is static and is the
utf8 value `258EAFA5-E914-47DA-95CA-C5AB0DC85B11`.

```javascript
// WS.mjs
import crypto     from 'crypto';
import { Buffer } from 'buffer';



const WS = {};


WS.upgrade = (socket, headers, callback) => {

	headers  = headers instanceof Object    ? headers  : null;
	callback = callback instanceof Function ? callback : null;

	if (headers !== null) {

		let nonce = headers['sec-websocket-key'] || null;
		if (nonce !== null) {

			let hash   = crypto.createHash('sha1').update(nonce + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('hex');
			let accept = Buffer.from(hash, 'hex').toString('base64');
			let blob   = [];

			blob.push('HTTP/1.1 101 WebSocket Protocol Handshake');
			blob.push('Upgrade: WebSocket');
			blob.push('Connection: Upgrade');
			blob.push('Sec-WebSocket-Accept: ' + accept);
			blob.push('Sec-WebSocket-Protocol: me-want-cookies');
			blob.push('Sec-WebSocket-Version: 13');
			blob.push('');
			blob.push('');

			// XXX: Flags are used later
			socket._is_server = true;
			socket._is_client = false;

			socket.write(blob.join('\r\n'));

			if (callback !== null) {
				callback(true);
			}

			return true;

		}

	} else {

		if (callback !== null) {
			callback(false);
		}

		return false;

	}

};


// Chapter: Receiving Web-Socket Frames
WS.receive = (socket, buffer, callback) => {};

// Chapter: Peer-To-Peer Web-Sockets
WS.ping = (socket) => {};

// Chapter: Sending Web-Socket Frames
WS.send = (socket, payload) => {};


export { WS };
```


## Web-Socket Framing

```text
|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
|     Extended payload length continued, if payload len == 127  |
+ - - - - - - - - - - - - - - - +-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
| Masking-key (continued)       |          Payload Data         |
+-------------------------------- - - - - - - - - - - - - - - - +
:                     Payload Data continued ...                :
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                     Payload Data continued ...                |
+---------------------------------------------------------------+
```

Web-Socket Frames can be a bit complicated when just looking at
the figure. Here's a bullet-point list of what to remember:

- Frames can be fragmented (because of TCP), so the first bit is the `fin` flag.
- The `rsv1`, `rsv2` and `rsv3` are Web-Socket Extension flags. If set to `1`, the payload can be processed differently.
- The `opcode` decides what kind of Web-Socket frame follows.
- The `client-to-server` transferred `mask flag` decides whether or not the payload needs to be XOR-masked.
- The `masking key` is `32 bits` long (4 bytes). It is only transferred when `mask flag` is set to `1`.
- The `server-to-client` transferred `mask flag` is always set to `0` and the data frame does not contain a masking key.
- Frames have a variable payload size. Payload length can be `7 bit`, `16 bit` or `64 bit`.
- Unknown `opcode` fields have to lead to a close frame response.


## Receiving Web-Socket Frames

The integration with our server-side implementation is quite easy.

In order to integrate it properly, the `WS.receive()` method has
to only call the `callback` when it was actually receiving a data
frame, so it will handle all the web-socket specific non-data-frame
logic internally so that no external code needs to get involved.

```javascript
// WS.mjs
WS.receive = (socket, buffer, callback) => {

	buffer   = buffer instanceof Buffer     ? buffer   : null;
	callback = callback instanceof Function ? callback : null;

	if (buffer !== null) {

		let data = _decode(socket, buffer);
		if (data !== null) {

			if (data.response !== null) {

				// Close Frame: Protocol Error
				// Ping and Pong Frames
				socket.write(data.response);

			} else if (data.fragment === true) {

				// Continuation Frame: Do nothing

			} else if (data.payload !== null) {

				if (callback !== null) {
					callback(data.payload);
				}

				return data.payload;

			}

			// Close Frame ends the socket
			if (data.close === true) {
				socket.end();
			}

		}

	} else {

		if (callback !== null) {
			callback(null);
		} else {
			return null;
		}

	}

};
```


### Decoding Logic

In order to have the full featureset, the implementation needs
to keep track of a couple of things which it will track in the
`chunk` variable and its properties.

- Every `socket` has to have its own `fragment` buffer.
- If `chunk.close` is `true`, it will lead to a Close Frame.
- If `chunk.payload` is not `null`, it was parsed successfully.
- If `chunk.fragment` is `true`, the `WS.receive()` method will ignore it and not call the `callback`.
- If `payload_length` is lower than or equal `125`, it is a `7 bit` extended payload field.
- If `payload_length` is `126`, it is a `16 bit` extended payload field.
- If `payload_length` is `127`, it is a `64 bit` extended payload field.


```javascript
// WS.mjs
const _decode = function(socket, buffer) {

	let fragment = socket.__fragment || null;
	if (fragment === null) {
		fragment = socket.__fragment = {
			operator: 0x00,
			payload:  Buffer.alloc(0)
		};
	}

	if (buffer.length <= 2) {
		return null;
	}

	let chunk = {
		close:    false,
		fragment: false,
		headers:  {},
		payload:  null,
		response: null
	};

	let fin            = (buffer[0] & 128) === 128;
	let operator       = (buffer[0] &  15);
	let mask           = (buffer[1] & 128) === 128;
	let mask_data      = Buffer.alloc(4);
	let payload_length = buffer[1] & 127;
	let payload_data   = null;

	if (payload_length <= 125) {

		if (mask === true) {
			mask_data    = buffer.slice(2, 6);
			payload_data = buffer.slice(6, 6 + payload_length);
		} else {
			mask_data    = null;
			payload_data = buffer.slice(2, 2 + payload_length);
		}

	} else if (payload_length === 126) {

		payload_length = (buffer[2] << 8) + buffer[3];

		if (payload_length > buffer.length) {
			chunk.fragment = true;
			return chunk;
		}

		if (mask === true) {
			mask_data    = buffer.slice(4, 8);
			payload_data = buffer.slice(8, 8 + payload_length);
		} else {
			mask_data    = null;
			payload_data = buffer.slice(4, 4 + payload_length);
		}

	} else if (payload_length === 127) {

		let hi = (buffer[2] * 0x1000000) + ((buffer[3] << 16) | (buffer[4] << 8) | buffer[5]);
		let lo = (buffer[6] * 0x1000000) + ((buffer[7] << 16) | (buffer[8] << 8) | buffer[9]);


		payload_length = (hi * 4294967296) + lo;

		if (payload_length > buffer.length) {
			chunk.fragment = true;
			return chunk;
		}

		if (mask === true) {
			mask_data    = buffer.slice(10, 14);
			payload_data = buffer.slice(14, 14 + payload_length);
		} else {
			mask_data    = null;
			payload_data = buffer.slice(10, 10 + payload_length);
		}

	}

	if (mask_data !== null) {
		payload_data = payload_data.map((value, index) => value ^ mask_data[index % 4]);
	}

	if (operator === 0x00) {
		// Chapter: Continuation Frame
	} else if (operator === 0x01) {
		// Chapter: Text Frame
	} else if (operator === 0x02) {
		// Chapter: Binary Frame
	} else if (operator === 0x08) {
		// Chapter: Close Frame
	} else if (operator === 0x09) {
		// Chapter: Ping Frame
	} else if (operator === 0x0a) {
		// Chapter: Pong Frame
	} else {
		// Chapter: Other Web-Socket Control Frames
	}

	return chunk;

};
```


### 0x00: Continuation Frame

The `Continuation Frame` is always sent after a `Text Frame`
or a `Binary Frame` and can both be `fragmented` and `unfragmented`,
which means it needs to work when `fin` is `0` and `fin` is `1`.

```javascript
// WS.mjs in _decode()

if (operator === 0x00) {

	// 0x00: Continuation Frame

	if (payload_data !== null) {

		let payload = Buffer.alloc(fragment.payload.length + payload_length);

		fragment.payload.copy(payload, 0);
		payload_data.copy(payload, fragment.payload.length);
		fragment.payload = payload;

	}


	if (fin === true) {
		chunk.payload     = fragment.payload;
		fragment.operator = 0x00;
		fragment.payload  = Buffer.alloc(0);
	}

}
```


### 0x01: Text Frame

The `Text Frame` is sent when `utf8` encoded text data is
transferred. It can both be `fragmented` and `unfragmented`.

```javascript
// Browser Example
let data   = JSON.stringify({ foo: 'bar' });
let socket = new WebSocket('ws://localhost:12345', [
	'me-want-cookies'
]);

socket.send(data); // Text Frame
```


```javascript
// WS.mjs in _decode()

if (operator === 0x01) {

	// 0x01: Text Frame (possibly fragmented)

	if (fin === true) {

		chunk.payload = payload_data;

	} else if (payload_data !== null) {

		let payload = Buffer.alloc(fragment.payload.length + payload_length);

		fragment.payload.copy(payload, 0);
		payload_data.copy(payload, fragment.payload.length);

		fragment.payload  = payload;
		fragment.operator = operator;

	}

}
```


### 0x02: Binary Frame

The `Binary Frame` is sent when a `blob` or a
binary-representing `Uint8Array` is transferred.
It can both be `fragmented` and `unfragmented`.

```javascript
let blob   = new Uint8Array(8);
let socket = new WebSocket('ws://localhost:12345', [
	'me-want-cookies'
]);

socket.send(blob); // Binary Frame
```

```javascript
// WS.mjs in _decode()

if (operator === 0x02) {

	// 0x02: Binary Frame (possibly fragmented)

	if (fin === true) {

		chunk.payload = payload_data;

	} else if (payload_data !== null) {

		let payload = Buffer.alloc(fragment.payload.length + payload_length);

		fragment.payload.copy(payload, 0);
		payload_data.copy(payload, fragment.payload.length);

		fragment.payload  = payload;
		fragment.operator = operator;

	}

}
```

### 0x08: Close Frame

The `Close Frame` is sent when both the `client`
or the `server` want to let the other side
close the connection.

So when a `Close Frame` is sent by the client,
the server will respond with a `Close Frame`,
and immediately afterwards close the connection
via `socket.end()`.

Additionally, a `Close Frame` contains a status
code as payload. In practice, only four status
codes are necessary.

- `1000` normal closure
- `1001` going away
- `1002` protocol error
- `1015` (only server) TLS encryption error

The other status codes are reserved in case a server
implementation wants to get fancy and do their
own thing (without Web Browser clients, I guess?),
but usually they never appear in the wild.

- `1003` terminate connection due to data error (e.g. only text frame supported, but binary frame received)
- `1007` data inconsistency (e.g. no `utf8` encoded text frame)
- `1008` policy violation
- `1009` message too big to process
- `1010` (only client) terminate connection because server did not confirm extensions
- `1011` (only server) unexpected error

In our implementation it is already integrated
in the `WS.receive()` method, so the `chunk.close`
has to be set to `true` and the `chunk.response`
has to be set to the confirming `Close Frame`.

```javascript
// WS.mjs in _decode()

if (operator === 0x08) {

	// 0x08: Connection Close Frame

	let buffer = Buffer.alloc(4);
	let code   = 1000; // normal connection close

	buffer[0] = 128 + 0x08; // close
	buffer[1] =   0 + 0x02; // unmasked (client and server)

	buffer[1] = (code >> 8) & 0xff;
	buffer[2] = (code >> 0) & 0xff;

	chunk.close    = true;
	chunk.response = buffer;

}
```


### 0x09: Ping Frame

The `Ping Frame` is sent by the client to the
server, which means it has a `masking key` and
the payload data is masked.

Additionally, the specification implies that
when a `Ping Frame` contains a payload, the
identical payload must be sent inside the
`Pong Frame` as well.

In practice, not a single Web Browser does
this. But technically, our implementation
wants to be prepared for everything, so it
has to respect that the payload has to be
appended optionally.

As the `payload_data` is unmasked in the
code before already, we don't have to deal
with it here and can just use the `buffer.write()`
method to append the already unmasked
`payload_data`.

```javascript
// WS.mjs in _decode()

if (operator === 0x09) {

	// 0x09: Ping Frame

	let buffer = Buffer.alloc(2 + (payload_data !== null ? payload_length : 0));

	buffer[0] = 128 + 0x0a; // fin, pong
	buffer[1] =   0 + 0x00; // unmasked

	if (payload_data !== null) {
		buffer.write(payload_data);
	}

	chunk.response = buffer;

}
```

### 0x0a: Pong Frame

The `Pong Frame` is sent by the server to the
client, which means it has no masking key and
the payload data is transferred without a mask.

Additionally, the specification implies that
a `Pong Frame` can be sent as a heartbeat of
the connection without any side-effects.

In response to a `Pong Frame`, both client
and server have to do nothing in return, so
it can simply be ignored.

Our implementation just needs to set `chunk.fragment`
to `true` in order to let the `WS.receive()`
silently ignore and continue.

```javascript
// WS.mjs in _decode()

if (operator === 0x0a) {

	// 0x0a: Pong Frame
	chunk.fragment = true;

}
```

### Other Web-Socket Control Frames

The specification reserves the `opcode`
range from `0x0b` to `0x0f`, but they have
no specified purpose yet.

So the `WS13` protocol implementation is
complete with the support of above control
frames, but our implementation should
send a close frame in case a Browser from
the future connects to our server.

```javascript
// WS.mjs in _decode()

if (operator === 0x00) {
	// ...
} else if (operator === 0x0a) {
	// ...
} else {

	// Close with Protocol Error

	let buffer = Buffer.alloc(4);
	let code   = 1002; // protocol error

	buffer[0] = 128 + 0x08; // close
	buffer[1] =   0 + 0x02; // unmasked (client and server)

	buffer[1] = (code >> 8) & 0xff;
	buffer[2] = (code >> 0) & 0xff;

	chunk.close    = true;
	chunk.response = buffer;

}
```


## Peer-To-Peer Web-Sockets

As you might have guessed by now, Web-Sockets can
be used in a peer-to-peer manner.

On the server-side, no `masking key` is used,
therefore the `payload_data` is sent unmasked.

On the client-side, a `masking key` is used,
therefore the `payload_data` is sent masked.

The client-side also sends a `Ping Frame`
from time to time. Usually this is done by
all major browsers every `60 seconds` or
somewhere around that value.

```javascript
// WS.mjs

WS.ping = (socket) => {

	// IMPORTANT: Use only on client-side
	// Otherwise a ping of death will happen ...

	let buffer = Buffer.alloc(6);

	buffer[0] = 128 + 0x09; // fin, ping
	buffer[1] = 128 + 0x00; // masked

	buffer[2] = (Math.random() * 0xff) | 0;
	buffer[3] = (Math.random() * 0xff) | 0;
	buffer[4] = (Math.random() * 0xff) | 0;
	buffer[5] = (Math.random() * 0xff) | 0;

	socket.write(buffer);

};
```


## Web-Socket Client

In order to integrate it with a client
implementation, it has to run in some kind
of `setInterval()` loop.

```javascript
// client.mjs
import crypto from 'crypto';
import net    from 'net';

import { WS  } from './WS.mjs';
const _NONCE = Buffer.alloc(16);


// XXX: Copy/Paste _parse_opening_handshake from './server.mjs';


const _send_handshake = function(socket) {

	let blob = [];

	for (let n = 0; n < 16; n++) {
		_NONCE[n] = Math.round(Math.random() * 0xff);
	}

	blob.push('GET / HTTP/1.1');
	blob.push('Connection: Upgrade');
	blob.push('Upgrade: websocket');
	blob.push('Sec-WebSocket-Key: ' + _NONCE.toString('base64'));
	blob.push('Sec-WebSocket-Protocol: me-want-cookies');
	blob.push('Sec-WebSocket-Version: 13');
	blob.push('');
	blob.push('');

	// XXX: Flags are used later
	socket._is_server = false;
	socket._is_client = true;

	socket.write(blob.join('\r\n'));

};


let client = new net.createConnection({
	host: 'localhost',
	port: 12345
}, _ => {
	_send_handshake(client);
});

client.on('data', buffer => {

	let nonce   = _NONCE.toString('base64');
	let hash    = crypto.createHash('sha1').update(nonce + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('hex');
	let expect  = Buffer.from(hash, 'hex').toString('base64');

	let headers = _parse_opening_handshake(buffer);
	if (headers['sec-websocket-accept'] === expect) {

		client.allowHalfOpen = true;
		client.setTimeout(0);
		client.setNoDelay(true);
		client.setKeepAlive(true, 0);

		client.removeAllListeners('timeout');
		client.removeAllListeners('data');

		client.on('data', buffer => {

			WS.receive(client, buffer, response => {
				console.log('Received response ', response);
			});

		});

		setTimeout(_ => {
			// Chapter: Sending Web-Socket Frames
			WS.send(client, JSON.stringify('{"foo":"bar"}'));
		}, 2000);

	}

});

client.on('error', _ => {});
client.on('close', _ => {});
client.on('timeout', _ => client.close());
```


## Sending Web-Socket Frames

The implementation currently respects all of
the server-side. But, in order to get full
peer-to-peer, the implementation also needs
a `WS.send()` method that encodes our data
that to transmit it correctly.

```javascript
// WS.mjs

WS.send = (socket, payload) => {

	payload = typeof payload === 'string' ? payload : null;


	let buffer = _encode(socket, Buffer.from(payload, 'utf8'));
	if (buffer !== null) {
		socket.write(buffer);
	}

};
```

## Encoding Logic

As our implementation used a `Text Frame`
before, the `_encode()` method will also
encode our data as a `Text Frame`.

I'll leave that up to the reader to implement
`Binary Frame` support, it's actually quite
easy now.

```javascript
// WS.mjs

const _encode = function(socket, data) {

	let buffer         = null;
	let mask           = false;
	let mask_data      = null;
	let payload_data   = null;
	let payload_length = data.length;


	let is_server = socket._is_server === true;
	if (is_server === true) {

		mask         = false;
		mask_data    = Buffer.alloc(4);
		payload_data = data.map(value => value);

	} else {

		mask      = true;
		mask_data = Buffer.alloc(4);

		mask_data[0] = (Math.random() * 0xff) | 0;
		mask_data[1] = (Math.random() * 0xff) | 0;
		mask_data[2] = (Math.random() * 0xff) | 0;
		mask_data[3] = (Math.random() * 0xff) | 0;

		payload_data = data.map((value, index) => value ^ mask_data[index % 4]);

	}


	if (payload_length > 0xffff) {

		// 64 Bit Extended Payload Length

		let lo = (payload_length |  0);
		let hi = (payload_length - lo) / 4294967296;

		buffer = Buffer.alloc((mask === true ? 14 : 10) + payload_length);

		buffer[0] = 128 + 0x01;
		buffer[1] = (mask === true ? 128 : 0) + 127;
		buffer[2] = (hi >> 24) & 0xff;
		buffer[3] = (hi >> 16) & 0xff;
		buffer[4] = (hi >>  8) & 0xff;
		buffer[5] = (hi >>  0) & 0xff;
		buffer[6] = (lo >> 24) & 0xff;
		buffer[7] = (lo >> 16) & 0xff;
		buffer[8] = (lo >>  8) & 0xff;
		buffer[9] = (lo >>  0) & 0xff;

		if (mask === true) {

			mask_data.copy(buffer, 10);
			payload_data.copy(buffer, 14);

		} else {

			payload_data.copy(buffer, 10);

		}

	} else if (payload_length > 125) {

		// 16 Bit Extended Payload Length

		buffer = Buffer.alloc((mask === true ? 8 : 4) + payload_length);

		buffer[0] = 128 + 0x01;
		buffer[1] = (mask === true ? 128 : 0) + 126;
		buffer[2] = (payload_length >> 8) & 0xff;
		buffer[3] = (payload_length >> 0) & 0xff;

		if (mask === true) {
			mask_data.copy(buffer, 4);
			payload_data.copy(buffer, 8);
		} else {
			payload_data.copy(buffer, 4);
		}

	} else {

		// 7 Bit Payload Length

		buffer = Buffer.alloc((mask === true ? 6 : 2) + payload_length);

		buffer[0] = 128 + 0x01;
		buffer[1] = (mask === true ? 128 : 0) + payload_length;

		if (mask === true) {
			mask_data.copy(buffer, 2);
			payload_data.copy(buffer, 6);
		} else {
			payload_data.copy(buffer, 2);
		}

	}

	return buffer;

};
```


## Reference Implementation

That's it. Our implementation is now fully peer-to-peer
ready and supports the complete `WS13` protocol.

In case you missed something in between the lines or
made a mistake, there's a reference implementation
available.

- [client.mjs](./implementers-guide-to-websockets/client.mjs)
- [server.mjs](./implementers-guide-to-websockets/server.mjs)
- [WS.mjs](./implementers-guide-to-websockets/WS.mjs)

I hope you feel now as brain-fucked as I did the first time.
And I hope you're enjoying your well-deserved beer now.

Cheers!

