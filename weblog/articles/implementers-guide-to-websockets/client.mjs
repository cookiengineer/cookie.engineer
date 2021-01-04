// client.mjs
import { Buffer } from 'buffer';
import crypto     from 'crypto';
import net        from 'net';
import { WS  }    from './WS.mjs';



const NONCE = Buffer.alloc(16);


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


// Chapter: Web-Socket Client
const send_handshake = function(socket) {

	let blob = [];

	for (let n = 0; n < 16; n++) {
		NONCE[n] = Math.round(Math.random() * 0xff);
	}

	blob.push('GET / HTTP/1.1');
	blob.push('Connection: Upgrade');
	blob.push('Upgrade: websocket');
	blob.push('Sec-WebSocket-Key: ' + NONCE.toString('base64'));
	blob.push('Sec-WebSocket-Protocol: me-want-cookies');
	blob.push('Sec-WebSocket-Version: 13');
	blob.push('');
	blob.push('');

	// XXX: Flags are used in WS.send() and WS.receive()
	socket._is_server = false;
	socket._is_client = true;

	socket.write(blob.join('\r\n'));

};


// Chapter: Web-Socket Client
let client = new net.createConnection({
	host: 'localhost',
	port: 12345
}, () => {
	send_handshake(client);
});

client.on('data', (buffer) => {

	let nonce  = NONCE.toString('base64');
	let hash   = crypto.createHash('sha1').update(nonce + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('hex');
	let expect = Buffer.from(hash, 'hex').toString('base64');

	let headers = parse_opening_handshake(buffer);
	if (headers['sec-websocket-accept'] === expect) {

		client.allowHalfOpen = true;
		client.setTimeout(0);
		client.setNoDelay(true);
		client.setKeepAlive(true, 0);

		client.removeAllListeners('timeout');
		client.removeAllListeners('data');

		client.on('data', (buffer) => {

			WS.receive(client, buffer, (response) => {
				console.log('Received response ', response);
			});

		});


		setTimeout(() => {
			// Chapter: Sending Web-Socket Frames
			WS.send(client, JSON.stringify('{"foo":"bar"}'));
		}, 2000);

	}

});

client.on('error',   () => {});
client.on('close',   () => {});
client.on('timeout', () => client.close());

