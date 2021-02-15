#!/usr/bin/env node


import fs           from 'fs';
import path         from 'path';
import process      from 'process';
import { console  } from './console.mjs';
import { MARKDOWN } from './MARKDOWN.mjs';



const ROOT     = process.env.PWD + '/weblog';
const DATABASE = [];
const TABSPACE = '\t' + new Array(255).fill('\t').join('');



const parseMeta = function(article) {

	let tmp = article.trim();
	if (tmp.startsWith('===')) {

		let meta = {
			crux: null,
			date: null,
			name: null,
			tags: null,
			time: null,
			type: null,
			word: null
		};

		let head = tmp.substr(3, tmp.indexOf('===', 3) - 3).trim();
		if (head.length > 0) {

			head.split('\n').forEach((line) => {

				if (line.startsWith('-')) line = line.substr(1);

				let tmp = line.trim().split(':');
				let key = tmp[0].trim();
				let val = tmp[1].trim();

				if (val.includes(',')) {
					meta[key] = val.split(',').map((v) => v.trim());
				} else {
					meta[key] = val;
				}

			});

		}

		let body = tmp.substr(tmp.indexOf('===', 3) + 3).trim();
		if (body.length > 0) {

			meta.word = body.split('\n').join(' ').split(' ').filter((v) => /[A-Za-z]+/g.test(v)).length;
			meta.time = Math.round(meta.word / 200);

		}

		if (typeof meta.tags === 'string') {
			meta.tags = [ meta.tags ];
		}

		if (typeof meta.type === 'string') {
			meta.type = [ meta.type ];
		}


		return meta;

	}


	return null;

};

const _walk_fix_url = function(nodes) {

	nodes.forEach((node) => {

		if (typeof node !== 'string') {

			if (node.type === 'a') {

				let href = node.href;
				if (href.startsWith('../')) {
					href = node.href = path.resolve('/weblog/articles', href);
				} else if (href.startsWith('./')) {
					href = node.href = path.resolve('/weblog/articles', href);
				}

				if (href.startsWith('https://github.com')) {
					node.state = 'icon-github';
				} else if (href.startsWith('https://gitlab.com')) {
					node.state = 'icon-gitlab';
				} else if (href.startsWith('https://instagram.com')) {
					node.state = 'icon-instagram';
				} else if (href.startsWith('https://linkedin.com')) {
					node.state = 'icon-linkedin';
				} else if (href.startsWith('https://medium.com')) {
					node.state = 'icon-medium';
				} else if (href.startsWith('https://reddit.com')) {
					node.state = 'icon-reddit';
				} else if (href.startsWith('https://') || href.startsWith('http://')) {
					node.state = 'icon-website';
				} else if (
					href.endsWith('.mjs')
					|| href.endsWith('.tar.gz')
					|| href.endsWith('.tar.xz')
					|| href.endsWith('.zip')
				) {
					node.state = 'icon-download';
				} else if (href.startsWith('/')) {
					node.state = 'icon-section';
				}

			} else if (node.type === 'img') {

				let src = node.src;
				if (src.startsWith('../')) {
					node.src = path.resolve('/weblog/articles', src);
				} else if (src.startsWith('./')) {
					node.src = path.resolve('/weblog/articles', src);
				}

			}

			if (node.nodes.length > 0) {
				_walk_fix_url(node.nodes);
			}

		}

	});

};

const renderArticle = function(template, entry) {

	let meta = entry.meta;
	let html = entry.html;

	template = template.split('${menu}').join('<!-- TBD -->');
	template = template.split('${title}').join(meta.name);
	template = template.split('${headline}').join(meta.name);
	template = template.split('${article}').join(html);
	template = template.split('${description}').join(meta.name);
	template = template.split('${keywords}').join(meta.tags.join(', '));

	return template;

};

const renderFeed = function(template) {

	let articles = [];

	DATABASE.sort((a, b) => {

		if (a.meta.date > b.meta.date) return -1;
		if (b.meta.date > a.meta.date) return  1;
		return 0;

	}).forEach((entry) => {

		let meta   = entry.meta;
		let file   = entry.file.split('.').slice(0, -1).join('.');
		let name   = meta.name;
		let tags   = meta.tags;
		let date   = new Date(meta.date).toUTCString();
		let chunk  = '';
		let indent = TABSPACE.substr(0, 2);

		chunk += indent + '<item>\n';
		chunk += indent + '\t<title>' + name + '</title>\n';
		chunk += indent + '\t<description>' + name + '</description>\n';
		chunk += indent + '\t<link>https://cookie.engineer/weblog/articles/' + file + '.html</link>\n';
		chunk += indent + '\t<category>' + tags.join('/') + '</category>\n';
		chunk += indent + '\t<pubDate>' + date + '</pubDate>\n';
		chunk += indent + '</item>';

		articles.push(chunk);

	});


	let date = new Date().toUTCString();

	template = template.replace('${articles}',     articles.join('\n').trim());
	template = template.replace('${copyright}',    '2018-' + new Date().getFullYear());
	template = template.replace('${date-build}',   date);
	template = template.replace('${date-publish}', date);

	return template;

};

const renderIndex = function(template) {

	let articles = [];

	DATABASE.sort((a, b) => {

		if (a.meta.date > b.meta.date) return -1;
		if (b.meta.date < a.meta.data) return  1;
		return 0;

	}).forEach((entry) => {

		let meta   = entry.meta;
		let file   = entry.file.split('.').slice(0, -1).join('.');
		let chunk  = '';
		let indent = TABSPACE.substr(0, 3);

		chunk += indent + '<article id="' + file.split(' ').join('-') + '" class="' + meta.type.join('-') + '">\n';
		chunk += indent + '\t<samp></samp>\n';
		chunk += indent + '\t<h3>' + meta.name + '</h3>\n';

		if (typeof meta.image === 'string') {
			chunk += indent + '\t<figure>\n';
			chunk += indent + '\t\t<a href="./articles/' + file + '.html" target="_blank"><img alt="Article Header Image" src="./articles/' + file + '.jpg" width="512" height="288"></a>\n';
			chunk += indent + '\t</figure>\n';
		}

		if (meta.crux !== null) {
			chunk += indent + '\t<p>' + meta.crux + '</p>\n';
		}

		chunk += indent + '\t<ul>\n';
		chunk += indent + '\t\t<li><i>Article Link:</i><a href="./articles/' + file + '.html">' + meta.name + '</a></li>\n';

		if (meta.tags !== null && meta.tags.length > 0) {
			chunk += indent + '\t\t<li><i>Categories:</i><span>' + meta.tags.join(', ') + '</span></li>\n';
		}

		chunk += indent + '\t\t<li><i>Publishing Date:</i><time datetime="' + meta.date + '">' + meta.date + '</time></li>\n';

		if (meta.time !== null && meta.word !== null) {
			chunk += indent + '\t\t<li><i>Reading Time:</i><span>ca. ' + meta.time + '-minute read (~' + meta.word + ' words)</span></li>\n';
		}


		chunk += indent + '\t</ul>\n';
		chunk += indent + '</article>';


		articles.push(chunk);

	});

	template = template.replace('${articles}', articles.join('\n').trim());

	return template;

};

const parseBody = function(article) {

	let tmp = article.trim();
	if (tmp.startsWith('===')) {
		tmp = tmp.substr(tmp.indexOf('===', 3) + 3).trim();
	}


	let data = MARKDOWN.parse(tmp);
	if (data.length > 0) {
		_walk_fix_url(data);
	}

	return data;

};

const renderBody = function(data) {

	let body = MARKDOWN.render(data);
	if (body !== null) {
		return body;
	}

	return '';

};



fs.readdir(ROOT + '/articles', (err, files) => {

	files.filter((file) => file.endsWith('.md')).forEach((file) => {

		fs.readFile(ROOT + '/articles/' + file, 'utf8', (err, article) => {

			console.log('-> reading ' + file);

			if (!err) {

				let meta = parseMeta(article);
				let body = parseBody(article);
				let html = renderBody(body);

				if (meta !== null && body !== null && html !== '') {


					if (
						typeof meta.date === 'string'
						&& /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/g.test(meta.date)
						&& meta.name !== null
						&& meta.tags instanceof Array
						&& meta.type instanceof Array
					) {

						DATABASE.push({
							file: file,
							meta: meta,
							body: body,
							html: html
						});

					}

					console.info('   OKAY');

				} else {

					console.error('   NOT OKAY');

				}

			}

		});

	});

});


setTimeout(() => {

	fs.readFile(ROOT + '/sources/index.tpl', 'utf8', (err, template) => {

		if (!err) {

			let index = renderIndex(template);
			if (index !== '') {
				fs.writeFile(ROOT + '/index.html', index, 'utf8', (err) => {

					console.log('-> rendering index.html');

					if (!err) {
						console.info('   OKAY');
					} else {
						console.error('   NOT OKAY');
					}

				});
			}

		} else {
			console.log('-> rendering index.html');
			console.error('   NOT OKAY');
		}

	});

	fs.readFile(ROOT + '/sources/feed.tpl', 'utf8', (err, template) => {

		if (!err) {

			let feed = renderFeed(template);
			if (feed !== '') {
				fs.writeFile(ROOT + '/feed.xml', feed, 'utf8', (err) => {

					console.log('-> rendering feed.xml');

					if (!err) {
						console.info('   OKAY');
					} else {
						console.error('   NOT OKAY');
					}

				});
			}

		} else {
			console.log('-> rendering feed.xml');
			console.error('   NOT OKAY');
		}

	});

	setTimeout(() => {

		fs.readFile(ROOT + '/sources/article.tpl', 'utf8', (err, template) => {

			console.log('-> reading article.tpl');

			if (!err) {

				console.info('   OKAY');

				DATABASE.forEach((entry) => {

					let article = renderArticle(template, entry);
					if (article !== '') {

						let file = entry.file.split('.').slice(0, -1).join('.');

						fs.writeFile(ROOT + '/articles/' + file + '.html', article, 'utf8', (err) => {

							console.log('-> rendering articles/' + file + '.html');

							if (!err) {
								console.info('   OKAY');
							} else {
								console.error('   NOT OKAY');
							}

						});

					}

				});

			} else {
				console.error('   NOT OKAY');
			}

		});

	}, 100);

}, 500);

