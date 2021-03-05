// server.mjs

import dns from 'dns';
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

				console.log('Receive Handshake Request', data);

				if (
					data.headers['@version'] === 5
					&& data.headers['auth'].includes('none')
				) {

					socket.removeAllListeners('data');


					socket.once('data', (request) => {

						SOCKS.receive(socket, request, (data) => {

							console.log('Receive Connection Request', data);

							// Chapter: Connection Status
							if (
								data.headers['@version'] === 5
								&& data.headers['@method'] === 'connect'
							) {

								let host   = data.payload.host   || null;
								let domain = data.payload.domain || null;
								let port   = data.payload.port   || null;

								if (host !== null && port !== null) {

									let tunnel = null;

									try {
										tunnel = net.connect({
											host: host,
											port: port
										}, () => {

											socket.pipe(tunnel);
											tunnel.pipe(socket);

											let status = {
												headers: {
													'@version': 5,
													'@status':  'success'
												},
												payload: {
													host: host,
													port: port
												}
											};

											console.log('Send Connection Status', status);
											SOCKS.send(socket, status);

										});
									} catch (err) {
										tunnel = null;
									}

									if (tunnel === null) {
										SOCKS.send(socket, {
											headers: {
												'@version': 5,
												'@status':  'error-network'
											},
											payload: null
										});
									}

								} else if (domain !== null && port !== null) {

									// TODO: Integrate IPv6 support
									dns.resolve4(domain, (err, addresses) => {

										if (err === null) {

											// TODO: Integrate timeout loop for addresses
											if (addresses.length > 0) {

												let tunnel = null;

												try {

													tunnel = net.connect({
														host: addresses[0],
														port: port
													}, () => {

														socket.pipe(tunnel);
														tunnel.pipe(socket);

														let status = {
															headers: {
																'@version': 5,
																'@status':  'success'
															},
															payload: {
																host: addresses[0],
																port: port
															}
														};

														console.log('Send Connection Status', status);
														SOCKS.send(socket, status);

													});

												} catch (err) {
													tunnel = null;
												}

												if (tunnel === null) {
													SOCKS.send(socket, {
														headers: {
															'@version': 5,
															'@status':  'error-network'
														},
														payload: null
													});
												}

											} else {
												SOCKS.send(socket, {
													headers: {
														'@version': 5,
														'@status':  'error-network'
													},
													payload: null
												});
											}

										} else {
											SOCKS.send(socket, {
												headers: {
													'@version': 5,
													'@status':  'error-network'
												},
												payload: null
											});
										}

									});

								} else {

									SOCKS.send(socket, {
										headers: {
											'@version': 5,
											'@status':  'error-blocked'
										},
										payload: null
									});

								}

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

