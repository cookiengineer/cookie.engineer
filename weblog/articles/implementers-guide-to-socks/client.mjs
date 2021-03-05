// client.mjs
import net       from 'net';
import { SOCKS } from './SOCKS.mjs';



// Chapter: SOCKS Client
let client = new net.createConnection({
	host: 'localhost',
	port: 1080
}, () => {

	let handshake = {
		headers: {
			'auth': [ 'none' ]
		}
	};

	// Chapter: Handshake Request
	console.log('Send Handshake Request', handshake);
	SOCKS.send(client, handshake);

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

		console.log('Receive Handshake Response', data);

		if (data.headers['@version'] === 0x05 && data.headers['auth'] === 'none') {

			// Chapter: Connection Status
			client.once('data', (status) => {

				SOCKS.receive(client, status, (data) => {

					console.log('Receive Connection Status', data);

					if (data.headers['@status'] === 'success') {
						console.log('Client would be ready to do a HTTP request to ' + data.payload.host + ':' + data.payload.port + ' now.');
						// TODO: client.write(HTTP_REQUEST);
						client.destroy();
					} else {
						console.error('Server responded with an Error: ' + data.headers['@status']);
						client.destroy();
					}

				});

			});

			setTimeout(() => {

				let request = {
					headers: {
						'@method': 'connect'
					},
					payload: {
						domain: 'cookie.engineer',
						port:   80 // HTTP
					}
				};

				// Chapter: Connection Request
				console.log('Send Connection Request', request);
				SOCKS.send(client, request);

			}, 1000);

		} else {
			client.destroy();
		}

	});

	SOCKS.receive(response);

});

client.on('error',   () => {});
client.on('close',   () => {});
client.on('timeout', () => client.destroy());

