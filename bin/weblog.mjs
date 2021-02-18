#!/usr/bin/env node


import fs           from 'fs';
import process      from 'process';
import { console  } from './console.mjs';
import { MARKDOWN } from './MARKDOWN.mjs';



const ROOT     = process.env.PWD + '/weblog';
const DATABASE = [];
const TEMPLATE = {
	'article':   fs.readFileSync(ROOT + '/source/article.tpl',   'utf8'),
	'feed':      fs.readFileSync(ROOT + '/source/feed.tpl',      'utf8'),
	'feed-item': fs.readFileSync(ROOT + '/source/feed-item.tpl', 'utf8'),
	'index':     fs.readFileSync(ROOT + '/source/index.tpl',     'utf8')
};

const renderArticle = (entry) => {

	return MARKDOWN.renderTemplate(TEMPLATE['article'], {
		body: MARKDOWN.renderBody(entry.data.body, '/weblog/articles'),
		crux: entry.data.meta.crux,
		name: entry.data.meta.name,
		tags: entry.data.meta.tags.join(', ')
	});

};

const renderFeed = (database) => {

	let items = database.sort((a, b) => {
		if (a.data.meta.date > b.data.meta.date) return -1;
		if (b.data.meta.date > a.data.meta.date) return  1;
		return 0;
	}).map((entry) => MARKDOWN.renderTemplate(TEMPLATE['feed-item'], {
		base: entry.base,
		date: new Date(entry.data.meta.date).toUTCString(),
		crux: entry.data.meta.crux || entry.data.meta.name,
		name: entry.data.meta.name,
		tags: entry.data.meta.tags.join('/')
	}));

	return MARKDOWN.renderTemplate(TEMPLATE['feed'].trim(), {
		date:  new Date().toUTCString(),
		year:  new Date().getFullYear(),
		items: items.join('').trim()
	});

};

const renderIndex = (database) => {

	let articles = database.sort((a, b) => {
		if (a.data.meta.date > b.data.meta.date) return -1;
		if (b.data.meta.date > a.data.meta.date) return  1;
		return 0;
	}).map((entry) => {

		let chunk  = '';
		let indent = '\t\t\t';

		chunk += indent + '<article id="' + entry.base + '" class="' + entry.data.meta.type.join('-') + '">\n';
		chunk += indent + '\t<samp></samp>\n';
		chunk += indent + '\t<h3>' + entry.data.meta.name + '</h3>\n';

		if (typeof entry.data.meta.image === 'string') {
			chunk += indent + '\t<figure>\n';
			chunk += indent + '\t\t<a href="./articles/' + entry.base + '.html" target="_blank"><img alt="Article Header Image" src="./articles/' + entry.data.meta.image + '" width="512" height="288"></a>\n';
			chunk += indent + '\t</figure>\n';
		}

		if (entry.data.meta.crux !== null) {
			chunk += indent + '\t<p>' + entry.data.meta.crux + '</p>\n';
		}

		chunk += indent + '\t<ul>\n';
		chunk += indent + '\t\t<li><i>Article Link:</i><a href="./articles/' + entry.base + '.html">' + entry.data.meta.name + '</a></li>\n';

		if (entry.data.meta.tags !== null && entry.data.meta.tags.length > 0) {
			chunk += indent + '\t\t<li><i>Categories:</i><span>' + entry.data.meta.tags.join(', ') + '</span></li>\n';
		}

		chunk += indent + '\t\t<li><i>Publishing Date:</i><time datetime="' + entry.data.meta.date + '">' + entry.data.meta.date + '</time></li>\n';

		if (entry.data.meta.time !== null && entry.data.meta.word !== null) {
			chunk += indent + '\t\t<li><i>Reading Time:</i><span>ca. ' + entry.data.meta.time + '-minute read (~' + entry.data.meta.word + ' words)</span></li>\n';
		}

		chunk += indent + '\t</ul>\n';
		chunk += indent + '</article>';

		return chunk;

	});

	return MARKDOWN.renderTemplate(TEMPLATE['index'].trim(), {
		articles: articles.join('\n').trim()
	});

};



fs.readdir(ROOT + '/articles', (err, files) => {

	console.log('');
	console.info('Parsing...');

	files.filter((file) => file.endsWith('.md')).forEach((file) => {

		fs.readFile(ROOT + '/articles/' + file, 'utf8', (err, buffer) => {

			if (err === null) {

				let base = file.split('.').slice(0, -1).join('.');
				let data = MARKDOWN.parse(buffer);
				if (data.meta.crux === null || data.meta.date === null) {
					console.warn('> "' + base + '.md" incomplete!');
				}

				DATABASE.push({
					base: base,
					data: data
				});

			}

		});

	});

	setTimeout(() => {
		console.info('Done.');
	}, 100);

});

setTimeout(() => {

	let errors = 0;


	console.log('');
	console.info('Rendering...');

	DATABASE.forEach((entry) => {

		let article = renderArticle(entry);

		fs.writeFile(ROOT + '/articles/' + entry.base + '.html', article, 'utf8', (err) => {

			if (err) {
				console.error('> "' + entry.base + '.html" failed.');
				errors++;
			} else {
				console.info('> "' + entry.base + '.html" updated.');
			}

		});

	});


	let feed = renderFeed(DATABASE.filter((entry) => {

		if (
			entry.data.meta.crux !== null
			&& entry.data.meta.tags.length > 0
			&& entry.data.body.length > 0
		) {
			return true;
		}

		return false;

	}));

	setTimeout(() => {

		fs.writeFile(ROOT + '/feed.xml', feed, 'utf8', (err) => {

			if (err) {
				console.error('> "feed.xml" failed.');
				errors++;
			} else {
				console.info('> "feed.xml" updated.');
			}

		});

	}, 100);


	let index = renderIndex(DATABASE.filter((entry) => {

		if (
			entry.data.meta.crux !== null
			&& entry.data.meta.tags.length > 0
			&& entry.data.body.length > 0
		) {
			return true;
		}

		return false;

	}));

	setTimeout(() => {

		fs.writeFile(ROOT + '/index.html', index, 'utf8', (err) => {

			if (err) {
				console.error('> "index.html" failed.');
				errors++;
			} else {
				console.info('> "index.html" updated.');
			}

		});

	}, 100);


	setTimeout(() => {

		if (errors > 0) {
			console.error('Fail.');
		} else {
			console.info('Done.');
		}

	}, 200);

}, 200);

