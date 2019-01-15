<!DOCTYPE html>
<html lang="en">
	<head>
		<title>${title} - Cookie Engineer's Web Log</title>

		<!-- Meta -->
		<meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=0.5, maximum-scale=2, user-scalable=yes">
		<meta name="apple-mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<meta http-equiv="X-UA-Compatible" content="IE=edge">
		<meta name="creator" content="Cookie Engineer">
		<meta name="description" content="${description}">
		<meta name="keywords" content="${keywords}">
		<meta name="generator" content="Hands of Cookie Engineer with some beer and VIM night coding sessions">
		<meta name="robots" content="index, follow">
		<link rel="alternate" type="application/rss+xml" href="../feed.xml">

		<!-- Social Meta -->
		<meta name="og:image" content="../../design/cookiengineer.png">
		<meta name="og:title" content="${title} - Cookie Engineer's Web Log">
		<meta name="og:description" content="${description}">
		<meta name="og:site_name" content="Cookie Engineer's Web Log">
		<meta name="og:type" content="article">

		<!-- Website Content -->
		<link rel="stylesheet" href="../../design/fontello.css">
		<link rel="stylesheet" href="../../design/layout.css">

		<!-- Website Design -->
		<link rel="stylesheet" href="../../design/weblog.css">

		<!-- Website Functionality -->
		<link rel="stylesheet" href="../../design/menu.css">
		<script src="../../design/menu.js"></script>

		<!-- Magic: Copy/Paste/Save -->
		<link rel="stylesheet" href="../../design/copypaste.css">
		<script src="../../design/copypaste.js"></script>
		<link rel="stylesheet" href="../../design/save.css">
		<script src="../../design/save.js"></script>
	</head>
	<body>
		<header>
			<aside id="menu" class="visible">
				<button id="menu-button"><i></i></button>
				${menu}
				<a class="icon-section" href="../index.html">Web Log</a>
				<a class="icon-section" href="../../index.html">Portfolio</a>
			</aside>
		</header>
		<section id="weblog">
			<h1>${headline}</h1>
			<article>
				${article}
			</article>
		</section>
		<footer>
			<p>Made with 💔 in Heidelberg, Germany. All rights (and jokes) reserved under European Law.</p>
		</footer>
		<dialog id="save">
			<article>
				<h3>Download Website <button id="save-close" title="Close Dialog">X</button></h3>
				<p>
					Usually, a Web Browser's <q>Save</q> functionality is severly broken
					and it auto-formats and auto-craps up all the HTML, CSS and JS.
					<br><br>
					This website includes Print Stylesheets, so you can also print it out
					by using <q>[Ctrl]+[P]</q> or the print feature of your Web Browser.
					<br><br>
					This website's source code is Open Source and can be downloaded from
					either of these repositories:
					<br><br>
					<a class="icon-github" href="https://github.com/cookiengineer/cookie.engineer" target="_blank">GitHub</a>
					or
					<a class="icon-gitlab" href="https://gitlab.com/cookiengineer/cookie.engineer" target="_blank">GitLab</a>
				</p>
			</article>
		</dialog>
	</body>
</html>
