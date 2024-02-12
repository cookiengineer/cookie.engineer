<!DOCTYPE html>
<html lang="en" prefix="og: http://ogp.me/ns#">
	<head>
		<title>Cookie Engineer's Web Log</title>

		<!-- Meta -->
		<meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=0.5, maximum-scale=2, user-scalable=yes">
		<meta name="apple-mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<meta http-equiv="X-UA-Compatible" content="IE=edge">
		<meta name="creator" content="Cookie Engineer">
		<meta name="description" content="Web Log of Cookie Engineer about Network Security and Software Architecture">
		<meta name="keywords" content="Software Architecture, Network Security, Network Analysis, Artificial Intelligence, Machine Learning">
		<meta name="generator" content="Hands of Cookie Engineer with some beer and VIM night coding sessions">
		<meta name="robots" content="index, follow">
		<link rel="alternate" type="application/rss+xml" href="./feed.xml">

		<!-- Social Meta -->
		<meta property="og:title" content="Cookie Engineer's Web Log">
		<meta property="og:site_name" content="Cookie Engineer's Web Log">
		<meta property="og:image" itemprop="image" content="https://cookie.engineer/design/about/avatar/cookiengineer.png">
		<meta property="og:url" content="https://cookie.engineer/weblog/index.html">
		<meta property="og:type" content="blog">
		<meta name="twitter:card" content="summary">
		<meta name="twitter:domain" content="cookie.engineer">
		<meta name="twitter:title" itemprop="name" content="Cookie Engineer's Web Log">
		<meta name="twitter:description" itemprop="description" content="Web Log of Cookie Engineer about Network Security and Software Architecture">

		<!-- Website Design -->
		<link rel="stylesheet" href="/design/layout/index.css">
		<link rel="stylesheet" href="/weblog/design/index.css">

		<!-- Website Functionality -->
		<link rel="stylesheet" href="/design/menu/index.css">
		<script src="/design/menu/index.js" defer></script>
		<link rel="stylesheet" href="/design/search/index.css">
		<script src="/design/search/index.js" defer></script>

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
				<a href="#welcome">Welcome</a>
				<a href="#search">Search</a>
				<a href="#weblog">Web&nbsp;Log</a>
			</aside>
		</header>
		<section id="welcome">
			<h1>Cookie Engineer's<br>Web Log.</h1>
			<article>
				<p>
					Welcome to my Web Log. This Web Log mostly contains my thoughts
					about Network Security, Network Analysis and Software Architecture.
				</p>
				<p>
					The idea is that I'm abusing this space to reflect on the Project
					Architectures when I happen to face some challenging problems.
					Well, that - or when I'm in the mood to brag about some nice new
					concepts or other things that I built with pride and prejudice.
				</p>
				<p>
					If you have a request for a new article or feedback, you can use the
					<a class="icon-section" href="/index.html#contact">Contact Form</a>
					of the Portfolio or create an Issue in the repository manually
					on <a class="icon-github" href="https://github.com/cookiengineer/cookie.engineer/issues" href="_blank">GitHub</a>
					or <a class="icon-gitlab" href="https://gitlab.com/cookiengineer/cookie.engineer/issues" href="_blank">GitLab</a>.
				</p>
				<p>
					There is also an RSS feed available. This is the subscription link
					so you can copy/paste it in your RSS Reader of choice:
					<a class="icon-download" rel="alternate" type="application/rss+xml" href="./feed.xml" download>/weblog/feed.xml</a>
				</p>
				<p>Enjoy your stay.</p>
			</article>
		</section>
		<section id="search">
			<h1><del>Search.</del> Recipe Creator.</h1>
			<article>
				<fieldset id="search-form">
					<div id="search-form-avatar"></div>
					<ul>
						<li class="hardware"><input type="checkbox" name="hardware" id="search-hardware" checked><label for="search-hardware">Hardware</label></li>
						<li class="software"><input type="checkbox" name="software" id="search-software" checked><label for="search-software">Software</label></li>
						<li class="research"><input type="checkbox" name="research" id="search-research" checked><label for="search-research">Research</label></li>
						<li class="legacy"><input type="checkbox" name="legacy" id="search-legacy" checked><label for="search-legacy">Legacy</label></li>
					</ul>
				</fieldset>
				<p>
					This <del>Search</del> Recipe Creator allows to modify what kind of articles are visible below.
					More selected ingredients means more articles are visible. Also, the cake is a lie.
				</p>
			</article>
		</section>
		<section id="weblog" class="timeline">
			<h1>Web Log.</h1>
{{range .Documents}}
			<article class="{{RenderStrings .Meta.Type "-"}}">
				<samp></samp>
				<h3>{{.Meta.Name}}</h3>
				<p>{{.Meta.Crux}}</p>
				<ul>
					<li><b>Article Link:</b><a href="/weblog/articles/{{.File}}">{{.Meta.Name}}</a></li>
					<li><b>Categories:</b><span>{{RenderStrings .Meta.Tags ", "}}</span></li>
					<li><b>Publishing Date:</b><time datetime="{{.Meta.Date}}">{{.Meta.Date}}</time></li>
					<li><b>Reading Time:</b><span>ca. {{RenderInteger .Statistics.Minutes}}-minute read (~{{RenderInteger .Statistics.Words}} words)</span></li>
				</ul>
			</article>{{end}}
		</section>
		<footer>
			<p>Made with 💔 in Heidelberg, Germany. All rights (and jokes) reserved under European Law.</p>
		</footer>
	</body>
</html>
