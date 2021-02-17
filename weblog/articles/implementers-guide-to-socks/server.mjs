// server.mjs
import net from 'net';

import { SOCKS } from './SOCKS.mjs';


// Chapter: SOCKS Server
let server = new net.Server({
	allowHalfOpen:  true,
	pauseOnConnect: true
});

server.on('connection', (socket) => {

	socket._is_server = true;

	socket.allowHalfOpen = true;
	socket.setNoDelay(true);
	socket.setKeepAlive(true, 0);


	socket.once('data', (request) => {

		if (request[0] === 0x05) {

			SOCKS.receive(socket, request, (data) => {

				console.log('Receiving Handshake Request', data);

				if (
					data.headers['@version'] === 5
					&& data.headers['auth'].includes('none')
				) {

					socket.removeAllListeners('data');


					socket.once('data', (request) => {

						SOCKS.receive(socket, request, (data) => {

							console.log('Receiving Connection Request', data);

							if (
								data.headers['@version'] === 5
								&& data.headers['@method'] === 'connect'
							) {

								// TODO: Handle connection and pipe data through it
								// TODO: Case for ipv4:port
								// TODO: Case for [ipv6]:port
								// TODO: Case for domain:port
								console.log(data.payload);

							} else {
								socket.end();
							}

						});

					});


					setTimeout(() => {

						SOCKS.send(socket, {
							headers: {
								'@version': 5,
								'auth':     'none'
							},
							payload: null
						});

					}, 0);

				} else {

					socket.end();

				}

			});

		} else {

			socket.end();

		}

	});

	socket.resume();

});

server.on('error', () => server.close());
server.on('close', () => (server = null));

server.listen(1080, null);

