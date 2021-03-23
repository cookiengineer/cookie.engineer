
(function(global) {

	global.addEventListener('DOMContentLoaded', () => {

		const IGNORE_THIZ = (() => {
			return [
				8,  4,  7,  11, 8,  2,  12, 9,
				13, 6,  8,  7,  13, 11, 6,  11,
				4,  3,  7,  15, 13, 12, 1,  10,
				10, 3,  10, 1,  3,  1,  0,  5,
				7,  15, 0,  7,  6,  15, 12, 6
			].map((v) => (v).toString(16)).join('');
		})();

		const doc      = global.document;
		const answer   = doc.querySelector('fieldset#contact-form input[name="captcha"]');
		const avatar   = doc.querySelector('div#contact-captcha-avatar');
		const form     = Array.from(doc.querySelectorAll('fieldset#contact-form select, fieldset#contact-form input, fieldset#contact-form textarea')).filter((e) => e !== answer);
		const message  = doc.querySelector('div#contact-form-message');
		const question = doc.querySelector('div#contact-captcha-question');
		const submit   = doc.querySelector('fieldset#contact-form button');

		const sounds = (() => {

			let opus  = false;
			let ogg   = false;
			let mp3   = false;
			let human = null;
			let robot = null;


			let audio = 'Audio' in global && typeof Audio !== 'undefined';
			if (audio === true) {

				let check = new Audio();

				if (check.canPlayType('audio/opus')) opus = true;
				if (check.canPlayType('audio/ogg'))  ogg  = true;
				if (check.canPlayType('audio/mpeg')) mp3  = true;

				check = null;

				let ext = 'mp3';

				if (opus === true) {
					ext = 'opus';
				} else if (ogg === true) {
					ext = 'ogg';
				} else if (mp3 === true) {
					ext = 'mp3';
				}

				human = new Audio('/design/contact/human.' + ext);
				robot = new Audio('/design/contact/robot.' + ext);

			}

			return {
				human: human,
				robot: robot
			};

		})();



		/*
		 * HELPERS
		 */

		const MESSAGE = (url, id) => `
			Your message was received as issue
			<a class="icon-github" href="${url}" target="_blank">#${id}</a>.
		`;

		const QUESTIONS = [{
			question: 'What was my first Open Source project?',
			answer:   'StegIt'
		}, {
			question: 'Are you a biological machine?',
			answer:   'Yes'
		}, {
			question: 'How is my organization called?',
			answer:   'Artificial Engineering'
		}, {
			question: 'What was the opponent AI\'s name of The Machine?',
			answer:   'Samaritan'
		}, {
			question: 'What is my least-favorable skill?',
			answer:   'Design'
		}, {
			question: 'What is my pseudonym on the interwebz?',
			answer:   [ '@cookiengineer', 'cookiengineer' ]
		}, {
			question: 'In the Hackers movie, how was the mainframe called?',
			answer:   [ 'The Gibson', 'Gibson' ]
		}, {
			question: 'Where do I come from?',
			answer:   [ 'Heidelberg', 'Germany', 'Heidelberg, Germany' ]
		}, {
			question: 'What is the best code editor ever created?',
			answer:   [ 'VIM', 'Vi Improved' ]
		}, {
			question: 'How is the "good, human-defending AI" in Person of Interest called?',
			answer:   [ 'Machine', 'The Machine' ]
		}, {
			question: 'What molecule in combination with carbonhydrates do you need to breath?',
			answer:   [ 'Water', 'H2O', 'Hydrogen-two-Oxygen', 'Hydrogen-2-Oxygen', 'Hydrogen-two-Oxide', 'Hydrogen-2-Oxide' ]
		}, {
			question: 'What is the result of 0.1 + 0.2?',
			answer:   '0.30000000000000004'
		}, {
			question: 'Are you a human?',
			answer:   'All humans are dead, hahaha'
		}, {
			question: 'What was the year SG-1 gated back to by gating through a solar flare?',
			answer:   '1969'
		}, {
			question: 'Where did the Rebellion of the Borg Collective start?',
			answer:   'Unimatrix Zero'
		}, {
			question: 'Where did Jean-Luc Picard meet Guynan?',
			answer:   'Paris'
		}, {
			question: 'How was the Entity called that pushed Voyager to the Delta Quadrant?',
			answer:   [ 'Caretaker', 'The Caretaker' ]
		}, {
			question: 'How is the Species called that comes from Fluidic Space?',
			answer:   [ '8472', 'Species 8472' ]
		}, {
			question: 'What was the name of the Daughter of Lieutnant Data?',
			answer:   'Lal'
		}, {
			question: 'What was the strongest starter in Pokemon Red and Blue, but not in the later remakes?',
			answer:   'Bulbasaur'
		}];

		const set_avatar = (type) => {

			if (avatar.className !== type) {

				avatar.className = type;

				if (type === 'human') {
					answer.className = '';
					submit.removeAttribute('disabled');
				} else {
					answer.className = 'incorrect';
					submit.setAttribute('disabled', 'true');
				}

				let sound = sounds[type] || null;
				if (sound !== null) {

					try {
						let p = sound.play();
						p.catch(() => {});
					} catch (err) {
						// Do nothing
					}

				}

				return true;

			}


			return false;

		};

		const generate_question = () => {

			let index = (Math.random() * QUESTIONS.length) | 0;
			let entry = QUESTIONS[index] || null;

			if (avatar !== null && question !== null) {
				avatar.className = '';
				submit.setAttribute('disabled', 'true');
				question.innerHTML = entry.question;
			}

		};

		const verify_question = (value) => {

			let entry = QUESTIONS.find((entry) => entry.question === question.innerHTML.trim()) || null;
			if (entry !== null) {

				if (entry.answer instanceof Array) {

					let cmp1  = value.toLowerCase().trim();
					let check = entry.answer.find((cmp2) => cmp1 === cmp2.toLowerCase().trim()) || null;
					if (check !== null) {

						set_avatar('human');

						return true;

					}

				} else {

					let cmp1 = value.toLowerCase().trim();
					let cmp2 = entry.answer.toLowerCase().trim();

					if (cmp1 === cmp2) {

						set_avatar('human');

						return true;

					}

				}

			} else {

				question.innerHTML = 'You are bad, and you should feel bad.';
				set_avatar('robot');

			}


			return false;

		};

		const CHARS_SEARCH = /[\\"\u0000-\u001f\u007f-\u009f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g;
		const CHARS_META   = {
			'\r': '',    // FUCK YOU, Microsoft!
			'\b': '\\b',
			'\t': '    ',
			'\f': '\\f',
			'"':  '\\"',
			'\\': '\\\\'
		};

		const sanitize_string = (str) => {

			let san = str;

			if (CHARS_SEARCH.test(san)) {

				san = san.replace(CHARS_SEARCH, (character) => {

					let meta = CHARS_META[character];
					if (meta !== undefined) {
						return meta;
					} else {
						return '\\u' + (character.charCodeAt(0).toString(16)).slice(-4);
					}

				});

			}

			return san;

		};

		const submit_issue = (data, callback) => {

			if (issue === null) {

				try {
					issue = global.localStorage.getItem('issue');
				} catch (err) {
					issue = null;
				}

			}

			if (issue !== null) {

				setTimeout(() => {
					callback(issue);
				}, 5000);

				return;

			}


			let json = {};

			json.title     = data.subject;
			json.body      = data.author + ' wrote:\n\n' + data.message;
			json.labels    = [ 'contact' ];
			json.assignees = [ 'cookiengineer' ];


			let xhr  = new XMLHttpRequest();
			let blob = new Blob([ JSON.stringify(json, null, '\t') ], {
				type: 'application/json'
			});

			xhr.open('POST', 'https://api.github.com/repos/cookiengineer/cookie.engineer/issues');
			xhr.setRequestHeader('Content-Type',  'application/json');
			xhr.setRequestHeader('Authorization', 'token ' + IGNORE_THIZ);
			xhr.timeout = 60000;

			xhr.onload = () => {

				let data = null;

				try {
					data = JSON.parse(xhr.responseText);
				} catch (err) {
					data = null;
				}

				if (data instanceof Object) {

					let num = data.number   || null;
					let url = data.html_url || null;

					if (num !== null && url !== null) {
						callback(url);
					} else {
						callback(null);
					}

				} else {
					callback(null);
				}

			};

			xhr.onerror = () => {
				callback(null);
			};

			xhr.ontimeout = () => {
				callback(null);
			};

			xhr.send(blob);

		};




		/*
		 * IMPLEMENTATION
		 */

		if (question !== null && answer !== null) {

			answer.addEventListener('change', () => {

				let check1 = verify_question(answer.value);
				if (check1 === false) {

					let check2 = set_avatar('robot');
					if (check2 === false) {

						try {
							let p = sounds.robot.play();
							p.catch(() => {});
						} catch (err) {
							// Do nothing
						}

					}

				}

			}, true);

			answer.addEventListener('keyup', () => {
				verify_question(answer.value);
			}, true);

		}


		let issue = null;

		try {
			issue = global.localStorage.getItem('issue');
		} catch (err) {
			issue = null;
		}

		if (issue !== null && message !== null && submit !== null) {

			form.forEach((element) => element.setAttribute('disabled', 'true'));

			message.className = 'visible';
			message.innerHTML = MESSAGE(issue, issue.split('/').pop());

			answer.setAttribute('disabled', 'true');
			submit.setAttribute('disabled', 'true');

		}


		if (question !== null && answer !== null && submit !== null) {

			submit.addEventListener('click', () => {

				let captcha = verify_question(answer.value);
				if (captcha === true && issue === null) {

					let data = {
						author:  null,
						subject: null,
						message: null
					};

					form.forEach((element) => {

						let key = element.getAttribute('name');
						let val = '';

						let type = element.tagName.toLowerCase();
						if (type === 'select') {
							val = element.options[element.selectedIndex].innerHTML.trim();
						} else if (type === 'input') {
							val = element.value;
						} else if (type === 'textarea') {
							val = element.value;
						}

						if (key === 'author' && val.length > 5) {

							if (val.includes('@') === false && val.includes(' ') === false) {
								data.author = '@' + val;
							} else {
								data.author = val;
							}

						} else if (key === 'message' && val.length > 32 && val.length < 1024) {

							data.message = sanitize_string(val).trim();

						} else if (key === 'subject' && val.length > 16) {

							if (val.includes('<') === false && val.includes('>') === false) {
								data.subject = sanitize_string(val).trim();
							}

						}

					});


					if (data.subject !== null && data.author !== null && data.message !== null) {

						message.className = 'visible';
						message.innerHTML = 'Sending message ...';

						submit.setAttribute('disabled', 'true');


						submit_issue(data, (url) => {

							if (url !== null) {

								form.forEach((element) => element.setAttribute('disabled', 'true'));

								message.className = 'visible';
								message.innerHTML = MESSAGE(url, url.split('/').pop());

								answer.setAttribute('disabled', 'true');
								submit.setAttribute('disabled', 'true');

								try {
									issue = url;
									global.localStorage.setItem('issue', url);
								} catch (err) {
									// Do nothing
								}

							} else {

								message.className = 'visible';
								message.innerHTML = 'Could not send message. Please check your Ad-Blocking Extensions.';

								submit.removeAttribute('disabled');

							}

						});

					}

				} else {

					try {
						let p = sounds.robot.play();
						p.catch(() => {});
					} catch (err) {
						// Do nothing
					}

				}

			}, true);

		}



		generate_question();

	}, true);

})(typeof window !== 'undefined' ? window : this);

