#!/usr/bin/env node


import { Buffer              } from 'buffer';
import { webcrypto as crypto } from 'crypto';
import fs                      from 'fs';
import process                 from 'process';
import { console             } from './console.mjs';



const ENCODER = new TextEncoder();
const DECODER = new TextDecoder();
const ROOT    = process.env.PWD + '/cv';
const ACTION  = ((action) => {

	if (
		action === 'encrypt'
		|| action === 'decrypt'
		|| action === 'remove'
	) {
		return action;
	}

	return null;

})(Array.from(process.argv).slice(2)[0]);

const PASSWORD = Array.from(process.argv).slice(2)[1] || null;



const digest = async (password) => {

	let digest = await crypto.subtle.digest('SHA-256', ENCODER.encode(password));

	return Buffer.from(digest).toString('hex');

};

const decrypt = async (buffer, password) => {

	let salt    = buffer.slice( 0, 16);
	let iv      = buffer.slice(16, 16 + 12);
	let pw_key  = await crypto.subtle.importKey('raw', ENCODER.encode(password), 'PBKDF2', false, [ 'deriveKey' ]);
	let aes_key = await crypto.subtle.deriveKey({
		name:       'PBKDF2',
		salt:       salt,
		iterations: 250000,
		hash:       'SHA-256'
	}, pw_key, {
		name:   'AES-GCM',
		length: 256
	}, false, [ 'decrypt' ]);

	let content = await crypto.subtle.decrypt({
		name: 'AES-GCM',
		iv:   iv
	}, aes_key, buffer.slice(16 + 12));

	return Buffer.from(DECODER.decode(content), 'utf8');

};

const encrypt = async (buffer, password) => {

	let salt    = crypto.getRandomValues(new Uint8Array(16));
	let iv      = crypto.getRandomValues(new Uint8Array(12));
	let pw_key  = await crypto.subtle.importKey('raw', ENCODER.encode(password), 'PBKDF2', false, [ 'deriveKey' ]);
	let aes_key = await crypto.subtle.deriveKey({
		name:       'PBKDF2',
		salt:       salt,
		iterations: 250000,
		hash:       'SHA-256'
	}, pw_key, {
		name:   'AES-GCM',
		length: 256
	}, false, [ 'encrypt' ]);


	let temp = await crypto.subtle.encrypt({
		name: 'AES-GCM',
		iv:   iv
	}, aes_key, ENCODER.encode(buffer.toString('utf8')));
	let content = new Uint8Array(temp);


	let output = new Uint8Array(salt.byteLength + iv.byteLength + content.byteLength);

	output.set(salt,    0);
	output.set(iv,      salt.byteLength);
	output.set(content, salt.byteLength + iv.byteLength);


	let result = Buffer.alloc(output.length);

	for (let o = 0, ol = output.length; o < ol; o++) {
		result[o] = output[o];
	}

	return result;

};


if (ACTION === null || PASSWORD === null) {

	console.info('');
	console.info('Encrypted CV Generator');
	console.info('');

	console.log('');
	console.log('Usage: cv decrypt "Decryption Password"');
	console.log('       cv encrypt "Encryption Password"');
	console.log('       cv remove  "Decryption Password"');
	console.log('');
	console.log('Usage Notes:');
	console.log('');
	console.log('    A decrypted CV template is necessary to be able to encrypt it again.');
	console.log('    The decrypted CV is stored at /cv/source/DECRYPTED.cv and isn\'t commited to git.');
	console.log('');
	console.log('Examples:');
	console.log('');
	console.log('    # Assumes password123 for already encrypted CV template (at /cv/source/<hash>.cv).');
	console.log('');
	console.log('    cv decrypt "password123";');
	console.log('    # Optionally customize CV at /cv/source/DECRYPTED.cv now');
	console.log('');
	console.log('    cv encrypt "Custom Password for Receiver";');
	console.log('    # Encrypted CV is now at /cv/source/<hash>.cv');
	console.log('');

	process.exit(1);

}


(async() => {

	if (ACTION === 'remove' && PASSWORD !== null) {

		let filename = await digest(PASSWORD);
		let result   = false;

		try {
			fs.unlinkSync(ROOT + '/source/' + filename + '.cv');
			result = true;
		} catch (err) {
			result = false;
		}

		if (result === true) {
			console.info('> Encrypted CV removed from "cv/source/' + filename + '.cv".');
		} else {
			console.warn('> Encrypted CV could not be removed.');
		}

	} else if (ACTION === 'decrypt' && PASSWORD !== null) {

		let encrypted = null;
		let filename  = await digest(PASSWORD);

		try {
			encrypted = fs.readFileSync(ROOT + '/source/' + filename + '.cv');
		} catch (err) {
			encrypted = null;
		}

		if (encrypted !== null) {

			console.info('Decrypt CV with password "' + PASSWORD + '" ...');

			let decrypted = await decrypt(encrypted, PASSWORD);

			let result = false;

			try {
				fs.writeFileSync(ROOT + '/source/DECRYPTED.cv', decrypted);
				result = true;
			} catch (err) {
				result = false;
			}

			if (result === true) {
				console.info('> Decrypted CV stored as "cv/source/DECRYPTED.cv".');
			} else {
				console.error('> Decrypted CV could not be stored.');
			}

		} else {
			console.error('Could not find Encrypted CV at "cv/source/' + filename + '.cv".');
		}

	} else if (ACTION === 'encrypt' && PASSWORD !== null) {

		let template = null;

		try {
			template = fs.readFileSync(ROOT + '/source/DECRYPTED.cv');
		} catch (err) {
			template = null;
		}

		if (template !== null) {

			console.info('Encrypt CV with password "' + PASSWORD + '" ...');

			let encrypted = await encrypt(template, PASSWORD);
			let decrypted = await decrypt(encrypted, PASSWORD);
			let filename  = await digest(PASSWORD);

			if (decrypted.toString('utf8') === template.toString('utf8')) {

				console.info('> Encryption/Decryption Self-Check passed.');

				let result = false;

				try {
					fs.writeFileSync(ROOT + '/source/' + filename + '.cv', encrypted);
					result = true;
				} catch (err) {
					result = false;
				}

				if (result === true) {
					console.info('> Encrypted CV stored as "cv/source/' + filename + '.cv".');
				} else {
					console.error('> Encrypted CV could not be stored.');
				}

			} else {
				console.error('> Encryption/Decryption Self-Check failed.');
			}

		} else {
			console.error('Could not find Unencrypted CV template at "cv/source/DECRYPTED.cv".');
		}

	}

})();

