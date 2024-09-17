<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
	<channel>
		<title>Cookie Engineer's Web Log</title>
		<description>Web Log about Software Architecture and Automation</description>
		<category>Computers/Software/Internet/Automation/Robotics/Artificial Intelligence/Machine Learning</category>
		<copyright>Copyright 2019-2024 Cookie Engineer</copyright>
		<language>en-us</language>
		<lastBuildDate>{{.Date}}</lastBuildDate>
		<managingEditor>@cookiengineer</managingEditor>
		<pubDate>{{.Date}}</pubDate>
		<image>
			<url>https://cookie.engineer/design/cookiengineer.png</url>
			<title>Cookie Engineer's Web Log</title>
			<link>https://cookie.engineer/weblog/index.html</link>
			<description>Web Log about Software Architecture and Automation</description>
			<width>256</width>
			<height>256</height>
		</image>{{range .Documents}}
		<item>
			<title>{{.Meta.Name}}</title>
			<description>{{.Meta.Crux}}</description>
			<link>https://cookie.engineer/weblog/articles/{{.File}}</link>
			<category>{{RenderStrings .Meta.Tags "/"}}</category>
			<pubDate>{{.Meta.Date}}</pubDate>
		</item>{{end}}
	</channel>
</rss>
