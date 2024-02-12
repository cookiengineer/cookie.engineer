===
- date: 2019-01-18
- name: Implementer's Guide to WebSockets
- tags: networking, nodejs, websockets
- type: software, legacy
- crux: A How-To Guide on building a WebSocket version 13 client and server from scratch, explaining related RFCs and potential quirks and problems with other implementations.
===

**Updated on 2021-09-28**

This time I implemented WebSocket support for [Tholian Stealth](https://github.com/tholian-network/stealth).

Soon came to realize that when implementing WebSockets from
scratch there is no go-to-and-know-everything resource available
on the internet. Most of the resources just use third-party
libraries and don't show how to implement the underlying
network protocol and frame parsing mechanisms.

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
Safari from the dark ages here (it's 2019, not 2011 after all).

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

let data = JSON.stringify({ foo: 'bar' });
let blob = new Uint8Array(8);

socket.send(data); // Text Frame
socket.send(blob); // Binary Frame
```


## Web-Socket Server

The demo will be implemented in modern node.js.

The server creation has to be done with the `net.Server()` interface,
as the data that we need to access is `raw TCP data` and our library
will have to support binary encodings.

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
import net    from 'net';
import { WS } from './WS.mjs';


// Chapter: Opening Handshake
const parse_opening_handshake = (buffer) => {

	let headers = {};
	return headers;

};

let server = new net.Server({
	allowHalfOpen:  true,
	pauseOnConnect: true
});

server.on('connection', (socket) => {

	socket.on('data', (buffer) => {

		let headers = parse_opening_handshake(buffer);
		if (
			headers['connection'] === 'Upgrade'
			&& headers['upgrade'] === 'websocket'
			&& headers['sec-websocket-protocol'] === 'me-want-cookies'
		) {

			WS.upgrade(socket, headers, (result) => {

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

	socket.on('error',   () => {});
	socket.on('close',   () => {});
	socket.on('timeout', () => socket.close());

	socket.resume();

});

server.on('error', () => server.close());
server.on('close', () => (server = null));

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

const parse_opening_handshake = (buffer) => {

	let headers = {};

	let req = buffer.toString('utf8');
	let raw = req.split('\n').map((line) => line.trim());

	if (raw[0].includes('HTTP/1.1')) {

		raw.slice(1).filter((line) => line.trim() !== '').forEach((line) => {

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
import { Buffer } from 'buffer';
import crypto     from 'crypto';



const WS = {};

// Chapter: Decoding Logic
WS.decode = (socket, buffer) => {};

// Chapter: Encoding Logic
WS.encode = (socket, packet) => {};

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

// Chapter: Receive Web-Socket Frames
WS.receive = (socket, buffer, callback) => {};

// Chapter: Peer-To-Peer Web-Sockets
WS.ping = (socket) => {};

// Chapter: Send Web-Socket Frames
WS.send = (socket, data, callback) => {};


export { WS };
```


## Web-Socket Framing

```plaintext
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


## Receive Web-Socket Frames

The integration of a receiving method for our WS library is quite easy.
Our own data structure for parsed Web-Socket Packets looks like this:

```javascript
let packet = {
	headers: {
		'@type':     (
			'request'     // Client to Server (masked frame)
			|| 'response' // Server to Client (unmasked frame)
		),
		'@operator': (
			0x00    // Continuation Frame (previous Frame was fragmented)
			|| 0x01 // Text Frame
			|| 0x02 // Binary Frame
			|| 0x08 // Connection Close Frame
			|| 0x09 // Ping (Client to Server)
			|| 0x0a // Pong (Server to Client)
		)
	},
	payload: Buffer.from('Example Payload', 'utf8')
}
```

The `WS.receive()` implementation will basically just delegate everything to
the `WS.decode()` Decoding Logic to keep things as easy as possible.

The stacking and concatenation of fragmented Text Frames and Binary Frames
that are followed by a Continuation Frame is left up as a task for the Reader.

```javascript
// WS.mjs
WS.receive = (socket, buffer, callback) => {

	buffer   = buffer instanceof Buffer     ? buffer   : null;
	callback = callback instanceof Function ? callback : null;

	if (buffer !== null) {

		let packet = WS.decode(socket, buffer);
		if (packet !== null) {

			if (callback !== null) {
				callback(packet);
			} else {
				return packet;
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
to keep track of a couple of things related to the Web-Socket
Wireframing Protocol.

- Every `socket` has to have its own `fragment` buffer for later stacking and concatenation of fragmented buffers.
- The operator code is represented by `packet.headers['@operator']`.
- A masked frame is represented by `packet.headers['@type'] = 'request'`.
- An unmasked frame is represented by `packet.headers['@type'] = 'response'`.
- If `packet.payload.length` is lower than or equal `125`, it is a `7 bit` extended payload field.
- If `packet.payload.length` is `126`, it is a `16 bit` extended payload field.
- If `packet.payload.length` is `127`, it is a `64 bit` extended payload field.


```javascript
// WS.mjs
WS.decode = (socket, buffer) => {

	if (buffer !== null) {

		if (buffer.length < 2) {
			return null;
		}


		let packet = {
			headers: {
				'@operator': null,
				'@status':   null,
				'@type':     null
			},
			overflow: null,
			payload:  null
		};


		let msg_payload  = null;
		let msg_overflow = null;
		let fin          = (buffer[0] & 128) === 128;
		let operator     = (buffer[0] &  15);
		let mask         = (buffer[1] & 128) === 128;


		let payload_length = buffer[1] & 127;
		if (payload_length <= 125) {

			if (mask === true && buffer.length >= payload_length + 6) {

				let mask_data = buffer.slice(2, 6);

				msg_payload  = buffer.slice(6, 6 + payload_length).map((value, index) => value ^ mask_data[index % 4]);
				msg_overflow = buffer.slice(6 + payload_length);

			} else if (buffer.length >= payload_length + 2) {

				msg_payload  = buffer.slice(2, 2 + payload_length);
				msg_overflow = buffer.slice(2 + payload_length);

			}

		} else if (payload_length === 126) {

			payload_length = (buffer[2] << 8) + buffer[3];

			if (mask === true && buffer.length >= payload_length + 8) {

				let mask_data = buffer.slice(4, 8);

				msg_payload  = buffer.slice(8, 8 + payload_length).map((value, index) => value ^ mask_data[index % 4]);
				msg_overflow = buffer.slice(8 + payload_length);

			} else if (buffer.length >= payload_length + 4) {

				msg_payload  = buffer.slice(4, 4 + payload_length);
				msg_overflow = buffer.slice(4 + payload_length);

			}

		} else if (payload_length === 127) {

			let hi = (buffer[2] * 0x1000000) + ((buffer[3] << 16) | (buffer[4] << 8) | buffer[5]);
			let lo = (buffer[6] * 0x1000000) + ((buffer[7] << 16) | (buffer[8] << 8) | buffer[9]);

			payload_length = (hi * 4294967296) + lo;

			if (mask === true && buffer.length >= payload_length + 14) {

				let mask_data = buffer.slice(10, 14);

				msg_payload  = buffer.slice(14, 14 + payload_length).map((value, index) => value ^ mask_data[index % 4]);
				msg_overflow = buffer.slice(14 + payload_length);

			} else if (buffer.length >= payload_length + 10) {

				msg_payload  = buffer.slice(10, 10 + payload_length);
				msg_overflow = buffer.slice(10 + payload_length);

			}

		}


		if (msg_overflow !== null && msg_overflow.length > 0) {
			packet.overflow = msg_overflow;
		}


		if (msg_payload !== null) {

			if (operator === 0x00) {

				// 0x00: Continuation Frame (fragmented)

				if (fin === true) {

					// TODO for Reader: Concat previously cached fragmented frames
					packet.headers['@operator'] = 0x00;
					packet.headers['@status']   = null;
					packet.headers['@type']     = mask === true ? 'request' : 'response';
					packet.payload              = msg_payload;

				} else {

					packet.headers['@operator'] = 0x00;
					packet.headers['@status']   = null;
					packet.headers['@type']     = mask === true ? 'request' : 'response';
					packet.payload              = msg_payload;

				}

			} else if (operator === 0x01 || operator === 0x02) {

				// 0x01: Text Frame (possibly fragmented)
				// 0x02: Binary Frame (possibly fragmented)

				if (fin === true) {

					packet.headers['@operator'] = operator;
					packet.headers['@status']   = null;
					packet.headers['@type']     = mask === true ? 'request' : 'response';
					packet.payload              = msg_payload;

				} else {

					// TODO for Reader: Cache fragmented frames
					packet.headers['@operator'] = operator;
					packet.headers['@status']   = null;
					packet.headers['@type']     = mask === true ? 'request' : 'response';
					packet.payload              = msg_payload;

				}

			} else if (operator === 0x08) {

				// 0x08: Connection Close Frame

				packet.headers['@operator'] = 0x08;
				packet.headers['@status']   = (msg_payload[0] << 8) + (msg_payload[1]);
				packet.headers['@type']     = mask === true ? 'request' : 'response';
				packet.payload              = null;

			} else if (operator === 0x09) {

				// 0x09: Ping Frame

				packet.headers['@operator'] = 0x09;
				packet.headers['@status']   = null;
				packet.headers['@type']     = 'request';
				packet.payload              = null;

			} else if (operator === 0x0a) {

				// 0x0a: Pong Frame

				packet.headers['@operator'] = 0x0a;
				packet.headers['@status']   = null;
				packet.headers['@type']     = 'response';
				packet.payload              = null;

			} else {

				// Connection Close Frame

				packet.headers['@operator'] = 0x08;
				packet.headers['@status']   = 1002;
				packet.headers['@type']     = mask === true ? 'request' : 'response';
				packet.payload              = msg_payload;

			}


			return packet;

		}

	}


	return null;

};

```


### 0x00: Continuation Frame

The `Continuation Frame` is always sent after a fragmented `Text Frame` or a
fragmented `Binary Frame`.

If the `Continuation Frame` itself is fragmented (`fin` is `0`) this means that
the previous `Text Frame` or `Binary Frame` is still not completely transferred.

If the `Continuation Frame` itself is unfragmented (`fin` is `1`) this means
that the previous `Text Frame` or `Binary Frame` is now completely transferred.

```javascript
// node.js Example
let fragmented_payload = Buffer.alloc(100);

WS.send(socket, {
	headers: {
		'@type':     'request',
		'@operator': 0x02
	},
	payload: payload.slice(0, 50)
});

WS.send(socket, {
	headers: {
		'@type':     'request',
		'@operator': 0x00
	},
	payload: payload.slice(50, 50)
});
```

On the Server-Side, however, the fragmented Frames are usually concatenated
together and then fired as if a single `Text Frame` or `Binary Frame` was sent.

As this is outside the context of this Guide, it's left up to the Reader to implement it.


### 0x01: Text Frame

The `Text Frame` is sent when `utf8` encoded text data is
transferred. It can both be `fragmented` and `unfragmented`.

```javascript
// Browser Example
let data   = JSON.stringify({ foo: 'bar' });
let socket = new WebSocket('ws://localhost:12345', [
	'me-want-cookies'
]);

socket.send(data);
```

```javascript
// node.js Example
let data = JSON.stringify({ foo: 'bar' };

WS.send(socket, {
	headers: {
		'@type': 'request',
		'@operator': 0x01
	},
	payload: Buffer.from(data, 'utf8')
});
```


### 0x02: Binary Frame

The `Binary Frame` is sent when a `blob` or a binary representing
`Uint8Array` is transferred. It can both be `fragmented` and `unfragmented`.

```javascript
// Browser Example
let blob   = new Uint8Array(10);
let socket = new WebSocket('ws://localhost:12345', [
	'me-want-cookies'
]);

socket.send(blob);
```

```javascript
// node.js Example
let data = Buffer.alloc(10);

WS.send(socket, {
	headers: {
		'@type': 'request',
		'@operator': 0x02
	},
	payload: data
});
```


### 0x08: Close Frame

The `Close Frame` is sent when both the Client or the Server want to
let the other side to close the current Web-Socket connection.

If a `Close Frame` is sent by the Client, the Server will respond with a
`Close Frame`, and immediately afterwards close the Socket via `socket.end()`.


A `Close Frame` contains a status code as payload. In practice, only
these four status codes are necessary:

- `1000` normal closure
- `1001` going away
- `1002` protocol error
- `1015` (only server) TLS encryption error

The other status codes are reserved in case a Server implementation wants to
get fancy and do their own thing (without Web Browser clients, I guess?),
but usually they never appear in the wild.

- `1003` terminate connection due to data error (e.g. only text frame supported, but binary frame received)
- `1007` data inconsistency (e.g. no `utf8` encoded text frame)
- `1008` policy violation
- `1009` message too big to process
- `1010` (only client) terminate connection because server did not confirm extensions
- `1011` (only server) unexpected error

```javascript
// node.js Example

WS.send(socket, {
	headers: {
		'@type': 'request',
		'@operator': 0x08,
		'@status': 1000
	},
	payload: null
});
```


### 0x09: Ping Frame

The `Ping Frame` is sent by the Client to the Server, which means it
has a `masking key` and the payload itself is masked.

The specification implies that when a `Ping Frame` contains a payload,
the identical payload must be sent inside the `Pong Frame` as well.

In practice, not a single Web Browser does this and payloads of a Pong
Frame are completely ignored by any implementation I've taken a look at.

```javascript
// node.js Example (for Client)

WS.send(socket, {
	headers: {
		'@type': 'request',
		'@operator': 0x09
	},
	payload: null
});
```


### 0x0a: Pong Frame

The `Pong Frame` is sent by the Server to the Client, which means it has
no masking key and the payload itself is unmasked.

The specification implies that a `Pong Frame` can be sent as a heartbeat
of the connection without any side-effects.

In response to a `Pong Frame`, both the Client and Server have to do
nothing in return, so they have to be ignored.

```javascript
// node.js Example (for Server)

socket.on('data', (data) => {

	let packet = WS.decode(data);
	if (packet !== null) {

		// Received Ping Frame, have to respond with Pong Frame
		if (packet.headers['@operator'] === 0x09) {
			WS.send(socket, {
				headers: {
					'@type': 'response',
					'@operator': 0x0a
				}
			});

		// Received Pong Frame, have to do nothing
		} else if (packet.headers['@operator'] === 0x0a) {
			// Do Nothing
		}

	}

});
```


### Other Web-Socket Control Frames

The specification reserves the `opcode` range from `0x0b` to `0x0f`,
but they have no specified purpose yet.

This means that our `WS13` protocol implementation is complete with
the support of above control frames, but our implementation should send
a close frame in case a Browser from the future connects to our Server
from the past.

```javascript
// node.js Example (for Server)

socket.on('data', (data) => {

	let packet = WS.decode(data);
	if (packet !== null) {

		// Received Ping Frame, have to respond with Pong Frame
		if (packet.headers['@operator'] === 0x09) {
			WS.send(socket, {
				headers: {
					'@type': 'response',
					'@operator': 0x0a
				},
				payload: null
			});

		// Received Pong Frame, have to do nothing
		} else if (packet.headers['@operator'] === 0x0a) {
			// Do Nothing
		} else if (packet.headers['@operator'] > 0x0b) {
			WS.send(socket, {
				headers: {
					'@type': 'response'
					'@operator': 0x08,
					'@status':   1002
				},
				payload: null
			});
		}

	}

});
```


## Web-Socket Client

The demo will be implemented in modern node.js.

The client has to be implemented with the `net.createConnection()`
interface, as the data that we need to access is `raw TCP data`
and our library needs to support binary encodings.

As node.js runs `libuv` in the background, which is of asynchronous
nature, we also have to make sure that everything gets send as soon
as possible by calling `socket.setNoDelay(true)`.

In order to integrate the Ping/Pong frames later with a client-side
implementation, it has to run inside a `setInterval()` loop that
sends a Ping Frame every X seconds. The amount of delay between
Ping and Pong Frames is not specified in the RFC, but it's recommended
to do this around every `60 seconds`.

```javascript
// client.mjs
import { Buffer } from 'buffer';
import crypto     from 'crypto';
import net        from 'net';
import { WS  }    from './WS.mjs';



const NONCE = Buffer.alloc(16);


// Chapter: Opening Handshake
// XXX: Copy/Paste parse_opening_handshake from './server.mjs';


const send_handshake = function(socket) {

	let blob = [];

	for (let n = 0; n < 16; n++) {
		NONCE[n] = Math.round(Math.random() * 0xff);
	}

	blob.push('GET / HTTP/1.1');
	blob.push('Connection: Upgrade');
	blob.push('Upgrade: websocket');
	blob.push('Sec-WebSocket-Key: ' + NONCE.toString('base64'));
	blob.push('Sec-WebSocket-Protocol: me-want-cookies');
	blob.push('Sec-WebSocket-Version: 13');
	blob.push('');
	blob.push('');

	socket.write(blob.join('\r\n'));

};


let client = new net.createConnection({
	host: 'localhost',
	port: 12345
}, () => {
	send_handshake(client);
});

client.on('data', (buffer) => {

	let nonce  = NONCE.toString('base64');
	let hash   = crypto.createHash('sha1').update(nonce + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('hex');
	let expect = Buffer.from(hash, 'hex').toString('base64');

	let headers = parse_opening_handshake(buffer);
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

		// TODO for Reader: This interval is usually between 60000 and 120000 ms
		setInterval(() => {

			WS.send(client, {
				headers: {
					'@type':     'request',
					'@operator': 0x09
				},
				payload: null
			});

		}, 10000);

		setTimeout(() => {

			// Chapter: Send Web-Socket Frames
			WS.send(client, {
				headers: {
					'@type':     'request',
					'@operator': 0x01
				},
				payload: Buffer.from(JSON.stringify('{"hello":"world!"}'))
			});

		}, 2000);

	}

});

client.on('error',   () => {});
client.on('close',   () => {});
client.on('timeout', () => client.close());
```


## Send Web-Socket Frames

The implementation currently respects all of the receiving functionality.
But in order to be used as a Web-Socket library, the `WS.send()` method
is still missing that transmits all our packets over the wire.

```javascript
// WS.mjs

WS.send = (socket, data, callback) => {

	data     = data instanceof Object       ? data     : { headers: {}, payload: null };
	callback = callback instanceof Function ? callback : null;


	let buffer = WS.encode(socket, {
		headers: data.headers || {},
		payload: data.payload || null
	});

	if (buffer !== null) {

		socket.write(buffer);

		if (callback !== null) {
			callback(true);
		} else {
			return true;
		}

	} else {

		if (callback !== null) {
			callback(false);
		} else {
			return false;
		}

	}

};
```

## Encoding Logic

The encoding logic does the opposite of the previously implemented
`WS.decode()` method, which represents the `Decoding Logic`.

```javascript
// WS.mjs

WS.encode = (socket, packet) => {

	let fin_payload = true; // TODO for Reader: Implement payload streaming support
	let msg_headers = Buffer.alloc(0);
	let msg_payload = Buffer.alloc(0);
	let msk_payload = Buffer.alloc(0);

	console.log(packet.headers);

	if (packet.payload instanceof Buffer) {
		msg_payload = packet.payload;
	} else if (packet.payload instanceof Object) {
		msg_payload = Buffer.from(JSON.stringify(packet.payload, null, '\t'), 'utf8');
	}

	if (packet.headers['@type'] === 'request') {

		msk_payload    = Buffer.alloc(4);
		msk_payload[0] = (Math.random() * 0xff) | 0;
		msk_payload[1] = (Math.random() * 0xff) | 0;
		msk_payload[2] = (Math.random() * 0xff) | 0;
		msk_payload[3] = (Math.random() * 0xff) | 0;

	} else if (packet.headers['@type'] === 'response') {

		msk_payload = Buffer.alloc(0);

	}

	if (
		packet.headers['@operator'] === 0x00
		|| packet.headers['@operator'] === 0x01
		|| packet.headers['@operator'] === 0x02
	) {

		if (msg_payload.length > 0xffff) {

			let lo = (msg_payload.length |  0);
			let hi = (msg_payload.length - lo) / 4294967296;

			msg_headers    = Buffer.alloc(10 + msk_payload.length);
			msg_headers[0] = (fin_payload === true   ? 128 : 0) + packet.headers['@operator'];
			msg_headers[1] = (msk_payload.length > 0 ? 128 : 0) + 127;
			msg_headers[2] = (hi >> 24) & 0xff;
			msg_headers[3] = (hi >> 16) & 0xff;
			msg_headers[4] = (hi >>  8) & 0xff;
			msg_headers[5] = (hi >>  0) & 0xff;
			msg_headers[6] = (lo >> 24) & 0xff;
			msg_headers[7] = (lo >> 16) & 0xff;
			msg_headers[8] = (lo >>  8) & 0xff;
			msg_headers[9] = (lo >>  0) & 0xff;

			if (msk_payload.length > 0) {
				msk_payload.copy(msg_headers, 10);
			}

		} else if (msg_payload.length > 125) {

			msg_headers    = Buffer.alloc(4 + msk_payload.length);
			msg_headers[0] = (fin_payload === true   ? 128 : 0) + packet.headers['@operator'];
			msg_headers[1] = (msk_payload.length > 0 ? 128 : 0) + 126;
			msg_headers[2] = (msg_payload.length >> 8) & 0xff;
			msg_headers[3] = (msg_payload.length >> 0) & 0xff;

			if (msk_payload.length > 0) {
				msk_payload.copy(msg_headers, 4);
			}

		} else {

			msg_headers    = Buffer.alloc(2 + msk_payload.length);
			msg_headers[0] = (fin_payload === true   ? 128 : 0) + packet.headers['@operator'];
			msg_headers[1] = (msk_payload.length > 0 ? 128 : 0) + msg_payload.length;

			if (msk_payload.length > 0) {
				msk_payload.copy(msg_headers, 2);
			}

		}

	} else if (packet.headers['@operator'] === 0x08) {

		let code = 1000;

		if (typeof packet.headers['@status'] === 'number') {
			code = packet.headers['@status'];
		}

		msg_headers    = Buffer.alloc(4);
		msg_headers[0] = 128 + packet.headers['@operator'];
		msg_headers[1] = (msk_payload.length > 0 ? 128 : 0) + 0x02;

		msg_payload = Buffer.from([
			(code >> 8) & 0xff,
			(code >> 0) & 0xff
		]);

	} else if (packet.headers['@operator'] === 0x09) {

		msg_headers    = Buffer.alloc(2);
		msg_headers[0] = 128 + packet.headers['@operator'];
		msg_headers[1] = 0   + 0x00;
		msg_payload    = Buffer.alloc(0);
		msk_payload    = Buffer.alloc(0);

	} else if (packet.headers['@operator'] === 0x0a) {

		msg_headers    = Buffer.alloc(2);
		msg_headers[0] = 128 + packet.headers['@operator'];
		msg_headers[1] = 0   + 0x00;
		msg_payload    = Buffer.alloc(0);
		msk_payload    = Buffer.alloc(0);

	} else {

		msg_headers    = Buffer.alloc(4);
		msg_headers[0] = 128 + packet.headers['@operator'];
		msg_headers[1] = 0   + 0x02;
		msg_headers[2] = (1002 >> 8) & 0xff;
		msg_headers[3] = (1002 >> 0) & 0xff;
		msg_payload    = Buffer.alloc(0);
		msk_payload    = Buffer.alloc(0);

	}


	return Buffer.concat([
		msg_headers,
		msg_payload
	]);

};
```


## Reference Implementation

That's it. Our implementation is now peer-to-peer ready and supports
the complete `WS13` protocol.

In case you missed something in between the lines or made a mistake,
there's a reference implementation available.

- [client.mjs](./implementers-guide-to-websockets/client.mjs)
- [server.mjs](./implementers-guide-to-websockets/server.mjs)
- [WS.mjs](./implementers-guide-to-websockets/WS.mjs)

