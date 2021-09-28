// WS.mjs
import { Buffer } from 'buffer';
import crypto     from 'crypto';



const WS = {};

// Chapter: Decoding Logic
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
		// let rsv1         = (buffer[0] &  64) === 64;
		// let rsv2         = (buffer[0] &  32) === 32;
		// let rsv3         = (buffer[0] &  16) === 16;
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

// Chapter: Encoding Logic
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


// Chapter: Receiving Web-Socket Frames
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


// Chapter: Sending Web-Socket Frames
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


export { WS };
