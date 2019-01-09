
# Cookie Engineer's Portfolio

You can visit my portfolio at [https://cookie.engineer](https://cookie.engineer).

This website is how I think every website should be.
Printable, shareable, interactive, fun to use and
semantically correct.

To be honest, take it or leave it. This is my website
and I like it. I think I did a great job at building
it.


## Features

- [x] Semantic HTML, CSS and JS
- [x] Works with deactivated JS
- [x] Dynamic Avatar Interaction
- [x] Awesome Sound Recordings
- [x] Interactive Search
- [x] Copy/Paste as CommonMark via CSS
- [x] Print Stylesheets


## Sources

- Icon Webfont created with Font Awesome Icons and [fontello](https://fontello.com).
- SVG Icons, Sounds and Graphics created by myself (@cookiengineer).


## Usage

The Website is a completely static website. Therefore
no dynamic backend language interpreter is necessary.

However, the [Web Log](./weblog) is written in CommonMark,
so new articles must be rendered into HTML by calling
the `bin/render-weblog.mjs` via node.js:

```bash
cd /path/to/cookie.engineer;

# Note that PWD must be the website root
node --experimental-modules ./bin/render-weblog.mjs;
```

## License

(c) 2018-2019 Cookie Engineer (@cookiengineer).
All rights reserved.

