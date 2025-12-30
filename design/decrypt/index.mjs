
(() => {

	const crypto  = window.crypto;
	const encoder = new TextEncoder();
	const decoder = new TextDecoder();

	const _arraybuffer_to_hex_string = (buffer) => {

		let array = new Uint8Array(buffer);
		let hex   = "";

		for (let a = 0; a < array.length; a++) {

			let value = array[a];
			let hi    = Math.floor(value / 16);
			let lo    = value % 16;
			let chars = "0123456789abcdef";

			hex += chars.charAt(hi);
			hex += chars.charAt(lo);

		}

		return hex;

	};

	const digest = async (password) => {

		let temp   = await crypto.subtle.digest('SHA-256', encoder.encode(password));
		let digest = new Uint8Array(temp);

		let str = "";

		for (let d = 0, dl = digest.byteLength; d < dl; d++) {
			str += String.fromCharCode(digest[d]);
		}

		let hex = "";

		for (let s = 0; s < str.length; s++) {

			let val = str.charCodeAt(s).toString(16);
			if (val.length < 2) {
				val = "0" + val;
			}

			hex += val;

		}

		return hex;

	};

	const decrypt = async (buffer, password) => {

		try {

			let salt    = new Uint8Array(buffer,  0, 16);
			let iv      = new Uint8Array(buffer, 16, 12);
			let blob    = new Uint8Array(buffer, 28);
			let pw_key  = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, [ "deriveBits", "deriveKey" ]);
			let raw_key = await crypto.subtle.deriveBits({
				name:       "PBKDF2",
				salt:       salt,
				iterations: 250000,
				hash:       {
					name: "SHA-256"
				}
			}, pw_key, 256);
			let aes_key = await crypto.subtle.importKey(
				"raw",
				raw_key,
				{ name: "AES-GCM", length: 256 },
				false,
				[ "decrypt" ]
			);

			console.log("Salt: ", _arraybuffer_to_hex_string(salt));
			console.log("IV: ", _arraybuffer_to_hex_string(iv));

			let content = await crypto.subtle.decrypt({
				name: "AES-GCM",
				iv:   iv
			}, aes_key, blob);

			return decoder.decode(content);

		} catch (err) {
			throw err;
		}

	};

	let filepath = document.querySelector("#decrypter input[data-name=\"filepath\"]");
	let password = document.querySelector("#decrypter input[data-name=\"password\"]");
	let button   = document.querySelector("#decrypter button[data-action=\"decrypt\"]");

	let search = window.location.search || "";
	if (search !== "" && filepath !== null && password !== null && decrypt !== null) {

		if (search.startsWith("?file=")) {
			filepath.value = search.substr(6).trim();
			password.removeAttribute("disabled");
		}

		password.addEventListener("keyup", () => {

			if (password.value.length > 1) {
				button.removeAttribute("disabled");
			} else {
				button.setAttribute("disabled", "");
			}

		});

		button.addEventListener("click", async () => {

			let filename = await digest(filepath.value.trim() + "|n0_th1s_1s_n0t_4_s33d_y0ung_ac0lyt3|" + password.value.trim());
			let buffer   = await fetch("/encrypted/" + filename + ".raw").then((response) => {
				return response.arrayBuffer();
			}).catch((err) => {
				console.error(err);
			});

			let decrypted = await decrypt(buffer, password.value).catch((err) => {
				console.error(err);
			});

			if (typeof decrypted === "string" && decrypted.length > 0) {

				let main = document.querySelector("main");
				if (main !== null) {
					main.innerHTML = decrypted.trim();
				}

			}

		});

	}

})();
