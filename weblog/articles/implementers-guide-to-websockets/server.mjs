// server.mjs
import net from 'net';

import { WS } from './WS.mjs';


// Chapter: Opening Handshake
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


// Chapter: Web-Socket Server
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

					socket.on('data', (buffer) => {

						WS.receive(socket, buffer, (request) => {
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

