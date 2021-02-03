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

