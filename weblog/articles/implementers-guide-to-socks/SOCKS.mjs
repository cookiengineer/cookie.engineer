
import { Buffer } from 'buffer';



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
				payload = {
					host: ip,
					port: port
				};
			}

		}

	} else if (type === 0x03) {

		// Chapter: Domain Payload
		// 0x03: Domain Payload

		let length     = buffer[1];
		let raw_domain = buffer.slice(2, 2 + length);
		let raw_port   = buffer.slice(2 + length, 2 + length + 2);

		if (raw_domain.length > 0 && raw_port.length === 2) {

			let domain = Buffer.from(raw_domain).toString('utf8');
			let port   = (raw_port[0] << 8) + (raw_port[1] & 0xff);
			if (domain.length > 0 && port > 0 && port < 65535) {
				payload = {
					domain: domain,
					port:   port
				};
			}

		}

	} else if (type === 0x04) {

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
				payload = {
					host: '[' + ip + ']',
					port: port
				};
			}

		}

	}

	return payload;

};

// Chapter: Encoding Logic
const encode = function(socket, data) {

	data = data instanceof Object ? data : { headers: {}, payload: null };


	if ((data.headers instanceof Object) === false) {
		data.headers = {};
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

			blob[2] = 0x00;

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

const encode_payload = function(payload) {

	payload = payload instanceof Object ? payload : { host: null, domain: null, port: 0 };


	if (typeof payload.host !== 'string') {
		payload.host = null;
	}

	if (typeof payload.domain !== 'string') {
		payload.domain = null;
	}

	if (typeof payload.port !== 'number') {
		payload.port = 0;
	}


	if (payload !== null) {

		if (payload.host !== null) {

			let data = [];
			let host = payload.host;
			if (host.includes('.') === true) {

				data.push(0x01);
				host.split('.').forEach((v) => {
					data.push(parseInt(v, 10));
				});

			} else if (host.includes(':') === true) {

				if (host.startsWith('[') === true) {
					host = host.substr(1);
				}

				if (host.endsWith(']') === true) {
					host = host.substr(0, host.length - 1);
				}

				data.push(0x04);
				host.split(':').forEach((v) => {
					data.push(parseInt(v.substr(0, 2), 16));
					data.push(parseInt(v.substr(2, 2), 16));
				});

			}

			data.push(payload.port >>> 8);
			data.push(payload.port & 0xff);

			return data;

		} else if (payload.domain !== null) {

			let data = [];
			let tmp  = Buffer.from(payload.domain, 'utf8');

			data.push(0x03);
			data.push(tmp.length);
			tmp.forEach((v) => {
				data.push(v);
			});

			data.push(payload.port >>> 8);
			data.push(payload.port & 0xff);

			return data;

		}

	}


	return null;

};



const SOCKS = {};

// Chapter: Receiving SOCKS Frames
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


// Chapter: Sending SOCKS Frames
SOCKS.send = (socket, data) => {

	data = data instanceof Object ? data : { headers: {}, payload: null };


	let buffer = encode(socket, data);
	if (buffer !== null) {
		socket.write(buffer);
	}

};


export { SOCKS };

