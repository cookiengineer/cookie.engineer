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
			date: null,
			name: null,
			tags: null,
			type: null
		};

		let raw = tmp.substr(3, tmp.indexOf('===', 3) - 3).trim();
		if (raw.length > 0) {

			raw.split('\n').forEach((line) => {

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
		let name   = '<a href="./articles/' + file + '.html" target="_blank">' + meta.name.split(' ').join('&nbsp;') + '</a>';
		let chunk  = '';
		let indent = TABSPACE.substr(0, 6);

		chunk += indent + '<tr class="' + meta.type.join('-') + '" title="Ingredients: ' + meta.type.join(', ') + '">\n';
		chunk += indent + '\t<td></td>\n';
		chunk += indent + '\t<td>' + meta.date + '</td>\n';
		chunk += indent + '\t<td>' + name + '</td>\n';
		chunk += indent + '\t<td>' + meta.tags.map((v) => v.split(' ').join('&nbsp;')).join(', ') + '</td>\n';
		chunk += indent + '</tr>';

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

			if (!err) {

				let meta = parseMeta(article);
				let body = parseBody(article);
				let html = renderBody(body);

				if (meta !== null && body !== null && html !== '') {

					console.log('< reading   ' + file + ' ... OKAY');

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

				} else {

					console.error('< reading   ' + file + ' ... NOT OKAY');

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
					if (!err) console.log('> rendering index.html ... OKAY');
				});
			}

		} else {
			console.error('> could not render index.html (no read/write access to template?');
		}

	});

	fs.readFile(ROOT + '/sources/feed.tpl', 'utf8', (err, template) => {

		if (!err) {

			let feed = renderFeed(template);
			if (feed !== '') {
				fs.writeFile(ROOT + '/feed.xml', feed, 'utf8', (err) => {
					if (!err) console.log('> rendering feed.xml ... OKAY');
				});
			}

		} else {
			console.error('> could not render feed.xml (no read/write access to template?');
		}

	});

	fs.readFile(ROOT + '/sources/article.tpl', 'utf8', (err, template) => {

		if (!err) {

			DATABASE.forEach((entry) => {

				let article = renderArticle(template, entry);
				if (article !== '') {

					let file = entry.file.split('.').slice(0, -1).join('.');

					fs.writeFile(ROOT + '/articles/' + file + '.html', article, 'utf8', (err) => {
						if (!err) console.log('> rendering articles/' + file + '.html ... OKAY');
					});

				}

			});

		} else {
			console.error('> could not render articles (no read/write access to template?');
		}

	});

}, 1000);

