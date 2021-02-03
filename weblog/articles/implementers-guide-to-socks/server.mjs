// server.mjs
import net from 'net';

import { SOCKS } from './SOCKS.mjs';


// Chapter: SOCKS Server
let server = new net.Server({
	allowHalfOpen:  true,
	pauseOnConnect: true
});

server.on('connection', (socket) => {

	socket.on('data', (buffer) => {

		// TODO: Reflect Basic Network Flow

	});

	socket.resume();

});

server.on('error', () => server.close());
server.on('close', () => (server = null));

server.listen(1080, null);

