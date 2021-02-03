// WS.mjs
import { Buffer } from 'buffer';
import crypto     from 'crypto';



// Chapter: Decoding Logic
const decode = (socket, buffer) => {

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

	} else if (operator === 0x01) {

		// Chapter: Text Frame
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

	} else if (operator === 0x02) {

		// Chapter: Binary Frame
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

	} else if (operator === 0x08) {

		// Chapter: Close Frame
		// 0x08: Connection Close Frame

		let buffer = Buffer.alloc(4);
		let code   = 1000; // normal connection close

		buffer[0] = 128 + 0x08; // close
		buffer[1] =   0 + 0x02; // unmasked (client and server)

		buffer[1] = (code >> 8) & 0xff;
		buffer[2] = (code >> 0) & 0xff;

		chunk.close    = true;
		chunk.response = buffer;

	} else if (operator === 0x09) {

		// Chapter: Ping Frame
		// 0x09: Ping Frame

		let buffer = Buffer.alloc(2 + (payload_data !== null ? payload_length : 0));

		buffer[0] = 128 + 0x0a; // fin, pong
		buffer[1] =   0 + 0x00; // unmasked

		if (payload_data !== null) {
			buffer.write(payload_data);
		}

		chunk.response = buffer;

	} else if (operator === 0x0a) {

		// Chapter: Pong Frame
		// 0x0a: Pong Frame
		chunk.fragment = true;

	} else {

		// Chapter: Other Web-Socket Control Frames
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

	return chunk;

};



// Chapter: Encoding Logic
const encode = (socket, data) => {

	let buffer         = null;
	let mask           = false;
	let mask_data      = null;
	let payload_data   = null;
	let payload_length = data.length;


	let is_server = socket._is_server === true;
	if (is_server === true) {

		mask         = false;
		mask_data    = Buffer.alloc(4);
		payload_data = data.map((value) => value);

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
WS.receive = (socket, buffer, callback) => {

	buffer   = buffer instanceof Buffer     ? buffer   : null;
	callback = callback instanceof Function ? callback : null;

	if (buffer !== null) {

		let data = decode(socket, buffer);
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


// Chapter: Sending Web-Socket Frames
WS.send = (socket, payload) => {

	payload = typeof payload === 'string' ? payload : null;


	let buffer = encode(socket, Buffer.from(payload, 'utf8'));
	if (buffer !== null) {
		socket.write(buffer);
	}

};


export { WS };
