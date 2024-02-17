<!DOCTYPE html>
<html lang="en" prefix="og:http://ogp.me/ns#">
	<head>
		<title>{{.Meta.Name}} - Cookie Engineer's Web Log</title>

		<!-- Meta -->
		<meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=0.5, maximum-scale=2, user-scalable=yes">
		<meta name="apple-mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<meta http-equiv="X-UA-Compatible" content="IE=edge">
		<meta name="creator" content="Cookie Engineer">
		<meta name="description" content="{{.Meta.Name}}">
		<meta name="keywords" content="{{RenderStrings .Meta.Tags ", "}}">
		<meta name="generator" content="Beer and VIM night coding sessions">
		<meta name="robots" content="index, follow">
		<link rel="alternate" type="application/rss+xml" href="../feed.xml">

		<!-- Social Meta -->
		<meta property="og:image" itemprop="image" content="https://cookie.engineer/design/about/avatar/cookiengineer.png">
		<meta property="og:title" content="{{.Meta.Name}} - Cookie Engineer's Web Log">
		<meta property="og:site_name" content="Cookie Engineer's Web Log">
		<meta property="og:description" content="{{.Meta.Crux}}">
		<meta property="og:type" content="article">
		<meta name="twitter:card" content="summary">
		<meta name="twitter:domain" content="cookie.engineer">
		<meta name="twitter:title" itemprop="name" content="{{.Meta.Name}} - Cookie Engineer's Web Log">
		<meta name="twitter:description" itemprop="description" content="{{.Meta.Crux}}">

		<!-- Website Design -->
		<link rel="stylesheet" href="/design/layout/index.css">
		<link rel="stylesheet" href="/weblog/design/index.css">

		<!-- Weblog Design -->
		<link rel="stylesheet" href="/weblog/design/layout/highlight.css">
		<link rel="stylesheet" href="/weblog/design/layout/article.css">
		<script src="/weblog/design/layout/highlight.js"></script>
		<script src="/weblog/design/layout/article.js" defer></script>

		<!-- Website Functionality -->
		<link rel="stylesheet" href="/design/menu/index.css">
		<script src="/design/menu/index.js" defer></script>

		<!-- Magic: Copy/Paste -->
		<link rel="stylesheet" href="/design/magic/index.css">
		<script src="/design/magic/index.js" defer></script>

	</head>
	<body>
		<header>
			<aside id="menu" class="visible">
				<a id="menu-button" href="#menu">Menu</a>
				<a class="icon-section" href="/index.html">About&nbsp;Me</a>
				<a class="icon-section" href="/projects.html">Projects</a>
				<a class="icon-section" href="/talks.html">Talks</a>
				<a class="icon-section" href="/contact.html">Contact</a>
				<a class="icon-section" href="/weblog/index.html">Web Log</a>
			</aside>
			<aside id="toc">{{range .Body}}{{if eq .Type "h2"}}
				<a class="section" href="#{{.Attributes.id}}">{{RenderElements .Children ""}}</a>{{else if eq .Type "h3" "h4"}}
				<a class="headline" href="#{{.Attributes.id}}">{{RenderElements .Children ""}}</a>{{else}}{{end}}{{end}}
			</aside>
		</header>
		<section id="article" class="article">
			<h1>{{.Meta.Name}}</h1>
			<article>
{{ .String "\t\t\t\t" }}
			</article>
		</section>
		<footer>
			<p class="print-not">Made with 💔 in Heidelberg, Germany. All rights (and jokes) reserved under European Law.</p>
			<p>&copy; Cookie Engineer (https://cookie.engineer). All rights reserved.</p>
		</footer>
	</body>
</html>
