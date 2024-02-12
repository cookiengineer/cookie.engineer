
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
- Highlight.js is embedded with `bash`, `css`, `diff`, `json`, `http`, `html`, `ini`, `javascript` languages.


## Usage

The Website is a completely static website. Therefore
no dynamic backend language interpreter is necessary.

However, the [Web Log](./weblog) is written in CommonMark,
so new articles must be rendered into HTML somehow.

This is done transparently by the [serve.sh](/toolchain/serve.sh)
which allows the [Editor](/weblog/editor.html) functionality.

It automatically re-renders related URLs when they are
loaded in the Browser (aka Hot Reload).

```bash
cd /path/to/cookie.engineer;

# Note that PWD must be the website root
bash ./toolchain/serve.sh;
```


Additionally, the CVs are stored in an AES-GCM encrypted
template format in order to preserve my privacy and to
protect me from stalkers...because I had issues with some
malicious actors in the past.

The CVs can be decrypted and encrypted by calling the
[cv.mjs](./toolchain/cv.mjs) via node.js, and in the Browser
they are decrypted via the Web Crypto API:

```bash
cd /path/to/cookie.engineer;

node ./bin/cv.mjs decrypt "old-password-of-already-encrypted-CV";

vim ./cv/source/DECRYPTED.cv; # Edit CV nao

node ./bin/cv.mjs encrypt "new-password";
```


## License

(c) 2018-2024 Cookie Engineer (@cookiengineer).
All rights reserved.

