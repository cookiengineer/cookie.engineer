#!/usr/bin/env node


import { Buffer   } from 'buffer';
import fs           from 'fs';
import http         from 'http';
import process      from 'process';
import { console  } from './console.mjs';
import { MARKDOWN } from './MARKDOWN.mjs';



const TEMPLATE     = fs.readFileSync(process.env.PWD + '/weblog/source/article.tpl', 'utf8');
const MIME_DEFAULT = { ext: 'bin', binary: true, format: 'application/octet-stream' };
const MIME = [

	// Media-Types are compliant with IANA assignments
	// https://www.iana.org/assignments/media-types

	// non-official
	{ ext: 'webmanifest', binary: false, format: 'application/manifest+json' },

	// application
	{ ext: 'abw',   binary: true,  format: 'application/x-abiword'                                                     },
	{ ext: 'azw',   binary: true,  format: 'application/vnd.amazon.ebook'                                              },
	{ ext: 'bin',   binary: true,  format: 'application/octet-stream'                                                  },
	{ ext: 'csh',   binary: false, format: 'application/x-csh'                                                         },
	{ ext: 'doc',   binary: true,  format: 'application/msword'                                                        },
	{ ext: 'docx',  binary: true,  format: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'   },
	{ ext: 'eot',   binary: true,  format: 'application/vnd.ms-fontobject'                                             },
	{ ext: 'js',    binary: false, format: 'application/javascript'                                                    },
	{ ext: 'json',  binary: false, format: 'application/json'                                                          },
	{ ext: 'mjs',   binary: false, format: 'application/javascript'                                                    },
	{ ext: 'odp',   binary: true,  format: 'application/vnd.oasis.opendocument.presentation'                           },
	{ ext: 'ods',   binary: true,  format: 'application/vnd.oasis.opendocument.spreadsheet'                            },
	{ ext: 'odt',   binary: true,  format: 'application/vnd.oasis.opendocument.text'                                   },
	{ ext: 'ogx',   binary: true,  format: 'application/ogg'                                                           },
	{ ext: 'pdf',   binary: true,  format: 'application/pdf'                                                           },
	{ ext: 'ppt',   binary: true,  format: 'application/vnd.ms-powerpoint'                                             },
	{ ext: 'pptx',  binary: true,  format: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' },
	{ ext: 'rtf',   binary: true,  format: 'application/rtf'                                                           },
	{ ext: 'sh',    binary: false, format: 'application/x-sh'                                                          },
	{ ext: 'ts',    binary: false, format: 'application/typescript'                                                    },
	{ ext: 'vsd',   binary: true,  format: 'application/vnd.visio'                                                     },
	{ ext: 'xhtml', binary: false, format: 'application/xhtml+xml'                                                     },
	{ ext: 'xls',   binary: true,  format: 'application/vnd.ms-excel'                                                  },
	{ ext: 'xlsx',  binary: true,  format: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'         },
	{ ext: 'xml',   binary: false, format: 'application/xml'                                                           },
	{ ext: 'xul',   binary: false, format: 'application/vnd.mozilla.xul+xml'                                           },

	// audio
	{ ext: '3gp',  binary: true, format: 'audio/3gpp' },
	{ ext: '3gpp', binary: true, format: 'audio/3gpp' },
	{ ext: 'aac',  binary: true, format: 'audio/aac'  },
	{ ext: 'ac3',  binary: true, format: 'audio/ac3'  },
	{ ext: 'mid',  binary: true, format: 'audio/midi' },
	{ ext: 'mp3',  binary: true, format: 'audio/mp3'  },
	{ ext: 'oga',  binary: true, format: 'audio/ogg'  },
	{ ext: 'ogg',  binary: true, format: 'audio/ogg'  },
	{ ext: 'wav',  binary: true, format: 'audio/wav'  },
	{ ext: 'weba', binary: true, format: 'audio/webm' },

	// font
	{ ext: 'otf',   binary: true, format: 'font/otf'   },
	{ ext: 'sfnt',  binary: true, format: 'font/sfnt'  },
	{ ext: 'ttf',   binary: true, format: 'font/ttf'   },
	{ ext: 'woff',  binary: true, format: 'font/woff'  },
	{ ext: 'woff2', binary: true, format: 'font/woff2' },

	// image
	{ ext: 'bmp',  binary: true, format: 'image/bmp'     },
	{ ext: 'emf',  binary: true, format: 'image/emf'     },
	{ ext: 'gif',  binary: true, format: 'image/gif'     },
	{ ext: 'ico',  binary: true, format: 'image/x-icon'  },
	{ ext: 'jp2',  binary: true, format: 'image/jp2'     },
	{ ext: 'jpeg', binary: true, format: 'image/jpeg'    },
	{ ext: 'jpg',  binary: true, format: 'image/jpeg'    },
	{ ext: 'png',  binary: true, format: 'image/png'     },
	{ ext: 'tif',  binary: true, format: 'image/tiff'    },
	{ ext: 'tiff', binary: true, format: 'image/tiff'    },
	{ ext: 'svg',  binary: true, format: 'image/svg+xml' },
	{ ext: 'webp', binary: true, format: 'image/webp'    },
	{ ext: 'wmf',  binary: true, format: 'image/wmf'     },

	// text
	{ ext: 'appcache', binary: false, format: 'text/cache-manifest' },
	{ ext: 'css',      binary: false, format: 'text/css'            },
	{ ext: 'csv',      binary: false, format: 'text/csv'            },
	{ ext: 'htm',      binary: false, format: 'text/html'           },
	{ ext: 'html',     binary: false, format: 'text/html'           },
	{ ext: 'ical',     binary: false, format: 'text/calendar'       },
	{ ext: 'md',       binary: false, format: 'text/x-markdown'     },
	{ ext: 'mf',       binary: false, format: 'text/cache-manifest' },
	{ ext: 'txt',      binary: false, format: 'text/plain'          },

	// video
	{ ext: 'avi',  binary: true, format: 'video/x-msvideo' },
	{ ext: 'm4v',  binary: true, format: 'video/mp4'       },
	{ ext: 'mov',  binary: true, format: 'video/quicktime' },
	{ ext: 'mp4',  binary: true, format: 'video/mp4'       },
	{ ext: 'mpeg', binary: true, format: 'video/mpeg'      },
	{ ext: 'mpg4', binary: true, format: 'video/mp4'       },
	{ ext: 'ogv',  binary: true, format: 'video/ogg'       },
	{ ext: 'qt',   binary: true, format: 'video/quicktime' },
	{ ext: 'webm', binary: true, format: 'video/webm'      },

	// other
	{ ext: '7z',   binary: true, format: 'application/x-7z-compressed'       },
	{ ext: 'bz',   binary: true, format: 'application/x-bzip'                },
	{ ext: 'bz2',  binary: true, format: 'application/x-bzip2'               },
	{ ext: 'epub', binary: true, format: 'application/epub+zip'              },
	{ ext: 'gz',   binary: true, format: 'application/x-gzip'                },
	{ ext: 'jar',  binary: true, format: 'application/jar-archive'           },
	{ ext: 'pac',  binary: true, format: 'application/x-ns-proxy-autoconfig' },
	{ ext: 'rar',  binary: true, format: 'application/x-rar-compressed'      },
	{ ext: 'tar',  binary: true, format: 'application/x-tar'                 },
	{ ext: 'zip',  binary: true, format: 'application/zip'                   }

];



const ROOT   = process.env.PWD;
const SERVER = http.createServer((request, response) => {

	let url    = request.url;
	let ext    = url.split('.').pop();
	let method = request.method;
	let mime   = MIME.find((m) => m.ext === ext) || MIME_DEFAULT;

	if (method === 'GET' && url === '/') {

		response.writeHead(307, {
			'Location': '/index.html'
		});

		response.end();

	} else if (method === 'GET' && url === '/weblog/articles/*.md') {

		response.writeHead(200, {
			'Content-Type': 'application/json'
		});

		fs.readdir(ROOT + '/weblog/articles', (err, files) => {
			response.end(JSON.stringify(files.filter((file) => file.endsWith('.md')), null, '\t'));
		});

	} else if (method === 'POST' && url.startsWith('/weblog/articles/') && url.endsWith('.md')) {

		let entry = {
			base: url.split('/').pop().split('.').slice(0, -1).join('.'),
			data: null
		};

		let buffer = Buffer.from('', 'utf8');

		request.on('data', (chunk) => {
			buffer = Buffer.concat([ buffer, chunk ]);
		});

		request.on('end', () => {

			let data = MARKDOWN.parse(buffer.toString('utf8'));
			if (
				data.meta.date !== null
				&& data.meta.name !== null
				&& data.meta.tags.length > 0
				&& data.meta.type.length > 0
				&& data.meta.crux !== null
			) {
				entry.data = data;
			}


			if (entry.data !== null) {

				fs.writeFile(ROOT + '/weblog/articles/' + entry.base + '.md', buffer, 'utf8', (err) => {

					if (err === null) {

						console.info('> "' + entry.base + '.md" saved.');

						response.writeHead(200);
						response.end();

					} else {

						console.error('> "' + entry.base + '.md" failed.');

						response.writeHead(304);
						response.end();

					}

				});

			} else {

				console.warn('> "' + entry.base + '.md" incomplete!');

				response.writeHead(406);
				response.end();

			}

		});

		request.resume();

	} else if (method === 'GET' && url.startsWith('/weblog/articles/') && url.endsWith('.html')) {

		let entry = {
			base: url.split('/').pop().split('.').slice(0, -1).join('.'),
			data: null
		};

		console.info('Re-Rendering "' + entry.base + '.html" ...');

		try {

			let buffer = fs.readFileSync(ROOT + '/weblog/articles/' + entry.base + '.md', 'utf8');
			let data   = MARKDOWN.parse(buffer);
			if (
				data.meta.date === null
				|| data.meta.name === null
				|| data.meta.tags.length === 0
				|| data.meta.type.length === 0
				|| data.meta.crux === null
			) {
				console.warn('> "' + entry.base + '.md" incomplete!');
			}

			entry.data = data;

		} catch (err) {
			entry.data = null;
		}


		if (entry.data !== null) {

			let buffer = Buffer.from(MARKDOWN.renderTemplate(TEMPLATE, {
				body: MARKDOWN.renderBody(entry.data.body, '/weblog/articles'),
				crux: entry.data.meta.crux,
				name: entry.data.meta.name,
				tags: entry.data.meta.tags.join(', ')
			}), 'utf-8');

			fs.writeFile(ROOT + '/weblog/articles/' + entry.base + '.html', buffer, 'utf8', (err) => {

				if (err === null) {
					console.info('> "' + entry.base + '.html" updated.');
				} else {
					console.error('> "' + entry.base + '.html" failed.');
				}

			});

			response.writeHead(200, {
				'Content-Type':   mime.format,
				'Content-Length': buffer.length,
				'Charset':        'utf-8'
			});

			response.end(buffer, 'utf-8');

		} else {

			console.error('> "' + entry.base + '.md" does not exist.');

			response.writeHead(404);
			response.end('');

		}

	} else if (method === 'GET' && url.startsWith('/')) {

		fs.readFile(ROOT + url, (err, buffer) => {

			if (err === null) {

				if (mime.binary === true) {

					response.writeHead(200, {
						'Content-Type':   mime.format,
						'Content-Length': buffer.length,
					});

					response.end(buffer);

				} else {

					response.writeHead(200, {
						'Content-Type':   mime.format,
						'Content-Length': buffer.length,
						'Charset':        'utf-8'
					});

					response.end(buffer, 'utf-8');

				}

			} else {

				response.writeHead(404);
				response.end('404: Not Found');

			}

		});

	} else {

		response.writeHead(403);
		response.end();

	}

});


SERVER.listen(8080);

console.info('Server running at http://localhost:8080/');

