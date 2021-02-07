===
- date: 2020-12-31
- name: Implementer's Guide to SOCKS
- tags: networking, nodejs, socks
- type: software, legacy
- crux: A How-To Guide on building a SOCKS version 4/5 client and server from scratch, explaining related RFCs and potential quirks and problems with other implementations.
===

Yesterday I was verifying that the SOCKS test suite of [Tholian Stealth](https://github.com/tholian-network/stealth)
is working and I realized that writing failsafe tests are not
as easy as someone might think. So here's my write-up about
the SOCKS protocol.

The problem with SOCKS in a nutshell is that it is not as well
documented as someone might think.

Most people are even unaware of the role that a SOCKS proxy plays
in between network connections and therefore don't know what exactly
a SOCKS proxy can or cannot do in regards to blocking ads and malicious
domains.

So I thought that a reference-class article for SOCKS4 and SOCKS5
would be nice, documenting its quirks and common pitfalls while
implementing those protocols.

For the implementation we're going to build in this article,
we only need plain node.js and its `net` core stack. The
implementation will be peer-to-peer, which means it can be used
for both the client-side and server-side whereas both sides are
implemented in node.js for the sake of simplicity.


## Introduction

First off, you have to know that the `SOCKS` protocol is specified as
[RFC1928](https://tools.ietf.org/html/rfc1928) and
[RFC1929](https://tools.ietf.org/html/rfc1929) and didn't change since
`1996` so it's somewhat safe to assume that this is the final version
of the network protocol.

The SOCKS protocol in general and its role is pretty much what telephone
operators did in the past. A client connects to the SOCKS proxy and
requests to connect to a specific target. The proxy tries to connect
to the target, and if it succeeds reaches through the connection to the
client.

```chat
Client: Please let me connect to IP 1.2.3.4.
Proxy:  Trying to connect... please hold the line ...
Proxy:  Here's the connection handle, any further data will be dispatched through automatically.
```

```chat
Client: Please let me connect to IP 1.2.3.4.
Proxy:  Trying to connect... please hold the line ...
Proxy:  Sorry, the given target is not reachable. Please try again later.
Proxy:  *hangs off the phone* Beep Beep Beep.
```

As both `SOCKS4` and `SOCKS4a` were proprietary protocols, they didn't
have any RFC. `SOCKS5` is referring a lot the `SOCKS4` protocol and
its featureset, so reading the RFC is quite complicated if you don't
know what the older protocol versions actually did feature-wise.

Usually though, most clients and servers that claim to support SOCKS5
actually only support the `user` and `password` authentication, not
the `IPv6` or `DNS/UDP` related features that come with it.

This implementation will focus mostly on the `IPv4` and `IPv6`
differences and will - for the sake of simplicity - only support `TCP`
based connections.


The `SOCKS4` featureset:

- connects to `IPv4` (TCP)

The `SOCKS4a` featureset:

- connects to `IPv4` (TCP)
- connects to `domain` (TCP)
- authentication via `user` is broken in practice (no password)

The `SOCKS5` featureset:

- connects to `IPv4` (TCP and UDP)
- connects to `IPv6` (TCP and UDP)
- connects to `domain` (TCP)
- authentication via `user` and `password`


## SOCKS Protocol and Network States

Describing SOCKS data frames can be kind of complicated, because the
interpretation of a SOCKS frame is different depending on its network
state. So I'm trying to document the different network states first,
so that you know what kind of states on both sides are possible.

We are also going to completely ignore the `SOCKS authentication methods`,
because they are broken across every single Browser; and implemented in
specification violating non-secure non-encrypted manners across every
piece of source code I've come across.

### SOCKS Version 4

The SOCKS **Version 4** network flow looks like this:

- Client sends Connection Request Frame
- Server responds with a Status Frame

... and that's pretty much it. Super simple.


**SOCKS Version 4 Connection Request Frame**:

```bash
+---------+---------+----+----+----+----+----+----+----+----+....+----+
| VERSION | COMMAND | DSTPORT |      DSTIP        | USERID       |NULL|
+---------+---------+----+----+----+----+----+----+----+----+....+----+
     1         1         2              4           variable       1
```

- `VERSION` (1 byte) represents the `SOCKS version`, which can be either of `0x04` or `0x05`.
- `COMMAND` (1 byte) represents the `SOCKS command`, which can be either of the Commands explained below.
- `DSTPORT` (2 bytes) represents the destination port from `1` to `65535`.
- `DSTIP` is an `IPv4` (4 bytes) represents the destination IP, and encodes 4 digits as `0x00` to `0xFF` respectively.
- `USERID` (variable byte length, followed by a `NULL` terminator byte) represents an authentication mechanism for a user-login; but without a password.

**SOCKS Version 4 Commands**:

- `0x01` represents `CONNECT` and is a TCP/IP connection request which lets the Server established the connection.
- `0x02` represents `BIND` and is a TCP/IP port binding to allow the Client to establish the connection themselves.


**SOCKS Version 4 Connection Status Frame**:

```bash
+---------+--------+----+----+----+----+----+----+
| VERSION | STATUS | DSTPORT |      DSTIP        |
+---------+--------+----+----+----+----+----+----+
     1         1        2              4
```

- `VERSION` (1 byte) represents the `SOCKS version`, which can be either of `0x04` or `0x05`.
- `STATUS` (1 byte) represents the `SOCKS status`, which can be either of the Status explained below.
- `DSTPORT` (2 bytes) represents the destination port from `1` to `65535`.
- `DSTIP` is an `IPv4` (4 bytes) represents the destination IP, and encodes 4 digits as `0x00` to `0xFF` respectively.

**SOCKS Version 4 Status Codes**:

- `0x5A` Request granted.
- `0x5B` Request rejected or failed.

**SOCKS Version 4 Status Codes for Authentication Mechanism**:

(I would not recommend to implement them)

- `0x5C` Request failed because Client's `identd` is not reachable from server.
- `0x5D` Request failed because Client's `identd` could not confirm the User ID.

### SOCKS Version 5

**Important**: The SOCKS Version 5 protocol is different in
its network flow and data frame structure; and it has a
reserved byte with a `0x00` value where the SOCKS Version 4
protocol would otherwise expect a non-NULL byte data.

Additionally, the order of `Destination Port` and `Destination Address`
is different from the order specified in SOCKS Version 4.


The SOCKS **Version 5** network flow looks like this:

1. Client and Server authenticate via handshake mechanism.
2. Server authenticates or responds with error message.
3. Client requests to connect or bind to an IPv4, IPv6 or domain.
4. Server responds with connection status.


**SOCKS Version 5 Handshake Request Frame**:

```bash
+---------+----+----+----+....+
| VERSION | NMETHODS| METHODS |
+---------+----+----+----+....+
     1         2      variable
```

**SOCKS Version 5 Handshake Response Frame**:

```bash
+---------+----+----+
| VERSION | METHOD  |
+---------+----+----+
     1         1
```

- `VERSION` (1 byte) represents the `SOCKS version`, which is `0x05`.
- `NMETHODS` (1 byte) represents the byte length of the following encoded `METHOD`s.
- `METHODS` (variable byte length) represents the encoded SOCKS methods.

**SOCKS Version 5 Handshake Methods**:

- `0x00` represents No Authentication required.
- `0x01` represents `GSSAPI` which is a "secure" context as defined per [RFC1961](https://tools.ietf.org/html/rfc1961).
- `0x02` represents `username/password` plaintext authentication.
- `0x80` to `0xFE` are reserved for private methods, but are never used in practice.
- `0xFF` represents No Acceptable methods (in a response).

**SOCKS Version 5 Connection Request**:

After the Client and Server have negotiated an Authentication Method,
the Client sends a Connection Request Frame to the Server.

```bash
+---------+---------+-----+------+----+----+----+----+
| VERSION | COMMAND | RSV | ATYP | DSTADDR | DSTPORT |
+---------+---------+-----+------+----+----+----+----+
     1         1       1      1    variable     2
```

- `VERSION` (1 byte) represents the `SOCKS version`, which is `0x05`.
- `COMMAND` (1 byte) represents either of the Commands explained below.
- `RSV` (1 byte) represents the reserved byte which has to be `0x00` (to be able to differ it from a SOCKS Version 4 Connection Request).
- `ATYP` (1 byte) represents the address type, which can be either of `0x01` (IPv4 address), `0x03` (domain name), `0x04` (IPv6 address).
- `DSTADDR` (variable) represents the destination address as an IPv4 (in 4 octets), the domain name (with a prefixed byte length), or an IPv6 (in 16 octets).
- `DSTPORT` (2 bytes) represents the destination port from `0x01` (`1`) to `0xFF` (`65535`).

**SOCKS Version 5 Commands**:

- `0x01` represents `CONNECT` and is a TCP/IP connection request which lets the Server established the connection and forward further packets.
- `0x02` represents `BIND` and is a TCP/IP port binding to allow the Client to establish the connection themselves.
- `0x03` represents `UDP ASSOCIATE` and is a UDP associate request which lets the Server establish the connection and forward further packets.

**SOCKS Version 5 Connection Status Frame**:

After the Client has sent the Connection Request frame, the Server responds
with a Connection Status Frame.

```bash
+---------+-------+-----+------+----+----+----+----+
| VERSION | REPLY | RSV | ATYP | BNDADDR | BNDPORT |
+---------+-------+-----+------+----+----+----+----+
     1        1      1      1    variable     2
```

- `VERSION` (1 byte) represents the `SOCKS version`, which is `0x05`.
- `REPLY` (1 byte) represents the reply message to the requested command and is either of the Replies explained below.
- `RSV` (1 byte) represents the reserved byte which has to be `0x00` (to be able to differ it from a SOCKS Version 4 Connection Request).
- `ATYP` (1 byte) represents the address type, which can be either of `0x01` (IPv4 address), `0x03` (domain name), `0x04` (IPv6 address).
- `BNDADDR` (variable) represents the server-bound destination address as an IPv4 (in 4 octets), the domain name (with a prefixed byte length), or an IPv6 (in 16 octets).
- `BNDPORT` (2 bytes) represents the server-bound destination port from `0x01` (`1`) to `0xFF` (`65535`).

**SOCKS Version 5 Replies**:

- `0x00` Success
- `0x01` General SOCKS Failure
- `0x02` Connection Not Allowed
- `0x03` Network Unreachable
- `0x04` Host Unreachable
- `0x05` Connection Refused
- `0x06` TTL (Time To Live) Expired
- `0x07` Command Not Supported
- `0x08` Address Type Not Supported


## SOCKS Client

The demo will be implemented using modern node.js.

The client has to be implemented with the `net.createConnection()`
interface, as the data that we need to access is `raw TCP data`
and our library needs to support binary encodings.

As node.js runs `libuv` in the background, which is of asynchronous
nature, we also have to make sure that everything gets send as soon
as possible by calling `socket.setNoDelay(true)`.

```javascript
// client.mjs
import net       from 'net';
import { SOCKS } from './SOCKS.mjs';



// Chapter: SOCKS Client
let client = new net.createConnection({
	host: 'localhost',
	port: 1080
}, () => {

	// Chapter: Handshake Request
	SOCKS.send(client, {
		headers: {
			'auth': [ 'none' ]
		}
	});

});

client.once('data', (response) => {

	client.allowHalfOpen = false;
	client.setTimeout(0);
	client.setNoDelay(true);
	client.setKeepAlive(true, 0);

	client.removeAllListeners('timeout');
	client.removeAllListeners('data');

	// Chapter: Handshake Response
	SOCKS.receive(client, response, (data) => {

		if (data.headers['@version'] === 0x05 && data.headers['auth'] === 'none') {

			// Chapter: Connection Status
			client.once('data', (status) => {

				SOCKS.receive(client, status, (data) => {

					console.log(data);

					if (data.headers['@status'] === 'success') {
						console.log('Client would be ready to do a HTTP request now.');
						// TODO: client.write(HTTP_REQUEST);
						client.close();
					} else {
						console.error('Server responded with an Error: ' + data.headers['@status']);
						client.close();
					}

				});

			});

			// Chapter: Connection Request
			SOCKS.send(client, {
				headers: {
					'@method': 'connect'
				},
				payload: {
					domain: 'cookie.engineer',
					port:   443 // HTTPS
				}
			});

		} else {
			console.error('Server did not authenticate us -_-');
			client.close();
		}

	});

	SOCKS.receive(response);

});

client.on('error',   () => {});
client.on('close',   () => {});
client.on('timeout', () => client.close());
```


## Handshake Request and Response

The initial Handshake Request that is done from the Client in order to
find out what kinds of `auth` methods the Server supports.

In the following example, we'll emulate a simple SOCKS Version 5 Client
to explain the previous example of the Client in more detail:

```javascript
// client-manual.mjs
import net from 'net';



const HANDSHAKE_REQUEST = [
	0x05, // SOCKS version
	0x02, // 2 Auth Methods are supported
	0x00, // methods[0]: No Authentication Required
	0x02  // methods[1]: Username/Password
];


net.connect({
	host: '127.0.0.1',
	port: 1080
}, () => {

	socket.once('data', (response) => {

		console.log('Handshake Response Frame', response);
		console.log('Server\'s SOCKS version (should be 0x05):', response[0]);
		console.log('Server\'s selected Auth Method (should be 0x00):', response[1]);

		// Chapter: Connection Request

	});

	socket.write(HANDSHAKE_REQUEST);

});
```


## Connection Request and Status

A SOCKS Server should be able to handle both `connect` and `bind` requests
for `IPv4` addresses, requested `domain`s, and `IPv6` addresses.

The Connection Request is sent by the Client after the Authentication Method
was completed, which means that for _all_ Connection Requests there is an
Handshake Request and Response Frame that preceeds it; as there are no
reusable Sessions in SOCKS and sockets cannot be reused.

```javascript
// client-manual.mjs
import net from 'net';



const HANDSHAKE_REQUEST = [
	0x05, // SOCKS version
	0x02, // 2 Auth Methods are supported
	0x00, // methods[0]: No Authentication Required
	0x02  // methods[1]: Username/Password
];

const CONNECTION_REQUEST = [

	0x05, // SOCKS version
	0x01, // CONNECT Command
	0x00, // Reserved (due to SOCKS4 compatibility)
	0x01, // IPv4 Address Type

	0x01, // 1.3.3.7
	0x03,
	0x03,
	0x07,

	80    // HTTPS-Connection

];


let client = net.createConnection({
	host: '127.0.0.1',
	port: 1080
}, () => {

	client.once('data', (response) => {

		console.log('Handshake Response Frame', response);

		if (response[0] === 0x05 && response[1] === 0x00) {

			client.once('data', (status) => {
				console.log('Connection Status Frame', status);
			});

			client.write(CONNECTION_REQUEST);

		}

	});

	client.write(HANDSHAKE_REQUEST);

});
```


## Receiving SOCKS Frames

The integration of a receiving method for our SOCKS library is quite easy.

```javascript
// SOCKS.mjs
SOCKS.receive = (socket, buffer, callback) => {

	buffer   = buffer instanceof Buffer     ? buffer   : null;
	callback = callback instanceof Function ? callback : null;

	if (buffer !== null) {

		let data = decode(socket, buffer);
		if (data !== null) {

			if (callback !== null) {
				callback(data);
			}

			return data;

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

The Decoding Logic is a bit more complex, as it has to respect the following states:

- Server: If `buffer.length` is greater than `3`, it is a `connect` or `bind` Connection Request.
- Server: If `buffer.length` is `3`, it is a Handshake Request with a single Authentication Method (which is what all Web Browsers use).
- Server: Unsupported: If a Client sends more than a single authentication method, we won't support it.
- Client: If `buffer.length` is `2`, it is a Handshake Response.
- Client: If `buffer.length` is greater than `2`, it is a Connection Status Response.


```javascript
// Chapter: Decoding Logic
const decode = function(socket, buffer) {

	let chunk = {
		headers: {},
		payload: null
	};

	if (buffer[0] === 0x05) {
		chunk.headers['@version'] = 5;
	} else if (buffer[0] === 0x04) {
		chunk.headers['@version'] = 4;
	}

	let is_server = socket._is_server === true;
	if (is_server === true) {

		// TODO: Support multiple Authentication Methods (buffer.length >= 3)
		if (buffer.length === 3) {

			let length  = buffer[1];
			let methods = buffer.slice(2, 2 + length);

			if (methods.length === length) {

				chunk.headers['auth'] = Array.from(methods).map((v) => {

					if (v === 0x00) {
						return 'none';
					} else if (v === 0x02) {
						return 'login';
					} else if (v === 0xff) {
						return 'error';
					}

					return null;

				}).filter((method) => method !== null);

			}

		} else if (buffer.length > 3) {

			let method = buffer[1];
			if (method === 0x01) {
				chunk.headers['@method'] = 'connect';
			} else if (method === 0x02) {
				chunk.headers['@method'] = 'bind';
			}

			let payload = decode_payload(buffer.slice(3));
			if (payload !== null) {
				chunk.payload = payload;
			}

		}

	} else {

		if (buffer.length === 2) {

			let auth = buffer[1];
			if (auth === 0x00) {
				chunk.headers['auth'] = 'none';
			} else if (auth === 0x02) {
				chunk.headers['auth'] = 'login';
			} else if (auth === 0xff) {
				chunk.headers['auth'] = 'error';
			}

		} else if (buffer.length > 2) {

			let reply = buffer[1];
			if (reply === 0x00) {
				chunk.headers['@status'] = 'success';
			} else if (reply === 0x01) {
				chunk.headers['@status'] = 'error';
			} else if (reply === 0x02) {
				chunk.headers['@status'] = 'error-blocked';
			} else if (reply === 0x03) {
				chunk.headers['@status'] = 'error-network';
			} else if (reply === 0x04) {
				chunk.headers['@status'] = 'error-host';
			} else if (reply === 0x05) {
				chunk.headers['@status'] = 'error-connection';
			} else if (reply === 0x07) {
				chunk.headers['@status'] = 'error-method';
			}

			if (buffer.length > 3) {

				let payload = decode_payload(buffer.slice(3));
				if (payload !== null) {
					chunk.payload = payload;
				}

			}

		}

	}

	return chunk;

};

const decode_payload = function(buffer) {

	let payload = null;

	let type = buffer[0];
	if (type === 0x01) {

		// Chapter: IPv4 Payload
		// 0x01: IPv4 Payload

	} else if (type === 0x03) {

		// Chapter: Domain Payload
		// 0x03: Domain Payload

	} else if (type === 0x04) {

		// Chapter: IPv6 Payload
		// 0x04: IPv4 Payload

	}

	return payload;

};
```


### 0x01: IPv4 Payload

The `IPv4 Payload` is sent to communicate that the Client wants to
`connect` or `bind` to a specific IP and a specific Port.

The encoded format of an IPv4 Payload is:

- `4 bytes` for the IP.
- `2 bytes` for the Port.

```javascript
// SOCKS.mjs in decode_payload()

if (type === 0x01) {

	// 0x01: IPv4 Payload

	let raw_host = buffer.slice(1, 5);
	let raw_port = buffer.slice(5, 7);

	if (raw_host.length === 4 && raw_port.length === 2) {

		let ip = [
			raw_host[0],
			raw_host[1],
			raw_host[2],
			raw_host[3]
		].join('.');
		let port = (raw_port[0] << 8) + (raw_port[1] & 0xff);

		if (port > 0 && port < 65535) {
			payload = ip + ':' + port;
		}

	}

}
```


### 0x03: Domain Payload

The `Domain Payload` is sent to communicate that the Client wants to
`connect` or `bind` to a specific domain (that the Server or Proxy
has to resolve first) and a specific Port.

In this case, the Server has to respond with a valid IP. If the IP
response is `0.0.0.0`, the Client must handle this as an unsuccessful
Connection Request.

The encoded format of a Domain Payload is:

- `1 byte` for the length of the Domain.
- `n bytes` for the Domain, encoded as a `utf8` string.
- `2 bytes` for the Port.


```javascript
// SOCKS.mjs in decode_payload()

if (type === 0x03) {

	// 0x03: Domain Payload

	let length     = buffer[1];
	let raw_domain = buffer.slice(1, 1 + length);
	let raw_port   = buffer.slice(1 + length, 1 + length + 2);

	if (raw_domain.length > 0 && raw_port.length === 2) {

		let domain = Buffer.from(raw_domain).toString('utf8');
		let port   = (raw_port[0] << 8) + (raw_port[1] & 0xff);
		if (domain.length > 0 && port > 0 && port < 65535) {
			payload = domain + ':' + port;
		}

	}

}
```


### 0x04: IPv6 Payload

The `IPv6 Payload` is sent to communicate that the Client wants to
`connect` or `bind` to a specific IP and a specific Port.

The encoded format of an IPv6 Payload is:

- `8 bytes` for the IP.
- `2 bytes` for the Port.

```javascript
// SOCKS.mjs in decode_payload()

if (type === 0x04) {

	let raw_host = buffer.slice(1, 17);
	let raw_port = buffer.slice(17, 19);

	if (raw_host.length === 16 && raw_port.length === 2) {

		let ip = [
			raw_host.slice( 0,  2).toString('hex'),
			raw_host.slice( 2,  4).toString('hex'),
			raw_host.slice( 4,  6).toString('hex'),
			raw_host.slice( 6,  8).toString('hex'),
			raw_host.slice( 8, 10).toString('hex'),
			raw_host.slice(10, 12).toString('hex'),
			raw_host.slice(12, 14).toString('hex'),
			raw_host.slice(14, 16).toString('hex')
		].join(':');
		let port = (raw_port[0] << 8) + (raw_port[1] & 0xff);

		if (port > 0 && port < 65535) {
			payload = '[' + ip + ']:' + port;
		}

	}

}
```







## Sending SOCKS Frames

### Encoding Logic

The Encoding Logic is a bit more complex, as it has to respect the following states:

- Server: If `headers['@version']` is set to `0x05` or `0x04`, set the SOCKS protocol version.
- Server: If `headers['auth']` is either `none` or `login`, transmit a Handshake Response Frame.
- Server: If `headers['@status']` is set, transmit a Connection Status Frame.
- Client: If `headers['auth']` is an `Array`, transmit a Handshake Request Frame.
- Client: If `headers['@method']` is set, transmit a Connection Request Frame.

```javascript
// Chapter: Encoding Logic
const encode = function(socket, data) {

	data = data instanceof Object ? data : { headers: {}, payload: null };


	if ((data.headers instanceof Object) === false) {
		data.headers = {};
	}

	if (typeof data.payload !== 'string') {
		data.payload = '0.0.0.0:0';
	}


	let blob = [ 0x05 ];

	if (data.headers['@version'] === 5) {
		blob[0] = 0x05;
	} else if (data.headers['@version'] === 4) {
		blob[0] = 0x04;
	}

	let is_server = socket._is_server === true;
	if (is_server === true) {

		if (typeof data.headers['auth'] === 'string') {

			if (data.headers['auth'] === 'none') {
				blob[1] = 0x00;
			} else if (data.headers['auth'] === 'login') {
				blob[1] = 0x02;
			} else {
				blob[1] = 0xff;
			}

		} else if (typeof data.headers['@status'] === 'string') {

			if (data.headers['@status'] === 'success') {
				blob[1] = 0x00;
			} else if (data.headers['@status'] === 'error-blocked') {
				blob[1] = 0x02;
			} else if (data.headers['@status'] === 'error-network') {
				blob[1] = 0x03;
			} else if (data.headers['@status'] === 'error-host') {
				blob[1] = 0x04;
			} else if (data.headers['@status'] === 'error-connection') {
				blob[1] = 0x05;
			} else if (data.headers['@status'] === 'error-method') {
				blob[1] = 0x07;
			} else if (data.headers['@status'] === 'error') {
				blob[1] = 0x01;
			}

			let payload = encode_payload(data.payload);
			if (payload !== null) {
				payload.forEach((v) => {
						blob.push(v);
						});
			}

		}

	} else {

		if ((data.headers['auth'] instanceof Array) === true) {

			let methods = data.headers['auth'].map((v) => {

				if (v === 'none') {
					return 0x00;
				} else if (v === 'login') {
					return 0x02;
				}

				return null;

			}).filter((method) => method !== null);
			let length = methods.length;

			blob[1] = length;
			methods.forEach((v) => {
				blob.push(v);
			});

		} else if (data.headers['@method'] === 'connect') {

			blob[1] = 0x01;
			blob[2] = 0x00;

			let payload = encode_payload(data.payload);
			if (payload !== null) {
				payload.forEach((v) => {
					blob.push(v);
				});
			}

		}

	}


	if (blob.length > 1) {
		return Buffer.from(blob);
	}


	return null;

};
```


## IPv4, Domain and IPv6 Payload

The decoding logic has been explained already in the previous chapters,
so it should be quite easy for you to handle the encoding of the payloads
and possible to write the `encode_payload` method yourself.


## SOCKS Server

The SOCKS Server is responsible for a lot of things, as it has
to handle the Handshake Requests and the Connection Requests
without a Session.

This means that for the Server has support the following states:

- Handshake Request with the `none` Authentication Method.
- Connection Request for the `IPv4` Payload.
- Connection Request for the `Domain` Payload.
- Connection Request for the `IPv6` Payload.
- The Connection Request's `connect` Method.

- Unsupported: Handshake Request with the `auth` Authentication Method is currently unsupported (as it's unsecure as already explained).
- Unsupported: The Connection Request's `bind` Method. It seems to be not used in the wild by any Web Browser anyways.


Additionally the `Domain` Payload includes resolving the Domain
into an IP before sending the Connection Status Frame, as the
Connection Status Frame can contain only resolved IPs for a
successfully proxied connection.


TODO: `server.mjs` Implementation


## Reference Implementation

That's it. Our implementation is now fully peer-to-peer
ready and supports the complete `SOCKS5` protocol.

In case you missed something in between the lines or
made a mistake, there's a reference implementation
available.

- [client.mjs](./implementers-guide-to-socks/client.mjs)
- [client-manual.mjs](./implementers-guide-to-socks/client-manual.mjs)
- [server.mjs](./implementers-guide-to-socks/server.mjs)
- [SOCKS.mjs](./implementers-guide-to-socks/SOCKS.mjs)

