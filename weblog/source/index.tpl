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
		<meta name="description" content="Web Log of Cookie Engineer about Software Architecture and Ups and Downs of Automation">
		<meta name="keywords" content="Artificial Intelligence, Machine Learning, Automation Engineer, Software Engineer, Mad Scientist">
		<meta name="generator" content="Hands of Cookie Engineer with some beer and VIM night coding sessions">
		<meta name="robots" content="index, follow">
		<link rel="alternate" type="application/rss+xml" href="./feed.xml">

		<!-- Social Meta -->
		<meta name="og:image" itemprop="image" content="https://cookie.engineer/design/cookiengineer.png">
		<meta name="og:title" content="Cookie Engineer's Web Log">
		<meta name="og:site_name" content="Cookie Engineer's Web Log">
		<meta name="og:type" content="blog">
		<meta name="twitter:card" content="summary">
		<meta name="twitter:domain" content="cookie.engineer">
		<meta name="twitter:title" property="og:title" itemprop="name" content="Cookie Engineer's Web Log">
		<meta name="twitter:description" property="og:description" itemprop="description" content="Web Log of Cookie Engineer about Software Architecture and Ups and Downs of Automation">

		<!-- Website Content -->
		<link rel="stylesheet" href="../design/fontello.css">
		<link rel="stylesheet" href="../design/layout.css">

		<!-- Website Design -->
		<link rel="stylesheet" href="../design/weblog/weblog.css">

		<!-- Website Functionality -->
		<link rel="stylesheet" href="../design/menu.css">
		<script src="../design/menu.js"></script>
		<link rel="stylesheet" href="../design/search.css">
		<script src="../design/search.js"></script>

		<!-- Magic: Copy/Paste/Save -->
		<link rel="stylesheet" href="../design/copypaste.css">
		<script src="../design/copypaste.js"></script>
		<link rel="stylesheet" href="../design/save.css">
		<script src="../design/save.js"></script>

		<!-- Magic: Highlight -->
		<link rel="stylesheet" href="../../design/weblog/highlight.css">
		<script src="../../design/weblog/highlight.js"></script>
	</head>
	<body>
		<header>
			<aside id="menu" class="visible">
				<button id="menu-button"><i></i></button>
				<a href="#welcome">Welcome</a>
				<a href="#search">Search</a>
				<a href="#weblog">Web Log</a>
				<a class="icon-section" href="../index.html">Portfolio</a>
			</aside>
		</header>
		<section id="welcome">
			<h1>Muh Web Log.</h1>
			<article>
				<p>
					Welcome to my Web Log. This Web Log mostly contains my thoughts
					about Software Engineering or Software Automation.
				</p>
				<p>
					The idea is that I'm abusing this space to reflect on the Project
					Architectures when I happen to face some challenging problems.
					Well, that - or when I'm in the mood to brag about some robots
					n' other cool shit that I built with pride and prejudice.
				</p>
				<p>
					If you have a request for a new article or feedback, you can use the
					<a class="icon-section" href="../index.html#contact">Contact Form</a>
					of the Portfolio or create an issue in the repository manually
					on <a class="icon-github" href="https://github.com/cookiengineer/cookie.engineer/issues" href="_blank">GitHub</a>
					or <a class="icon-gitlab" href="https://gitlab.com/cookiengineer/cookie.engineer/issues" href="_blank">GitLab</a>.
				</p>
				<p>
					There is also an RSS feed available. This is the subscription link
					so you can copy/paste it in your preferred RSS Feed Reader software:
					<a class="icon-download" rel="alternate" type="application/rss+xml" href="./feed.xml" download>/weblog/feed.xml</a>
				</p>
				<p>
					I hope you'll find this Web Log interesting.
					<br>
					Enjoy your stay.
				</p>
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
		<section id="weblog">
			<h1>Web Log.</h1>
			${articles}
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
