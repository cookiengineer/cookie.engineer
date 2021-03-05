
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

	80    // HTTP

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

