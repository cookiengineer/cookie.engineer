
# Cookie Engineer's Portfolio

You can visit my portfolio at [https://cookie.engineer](https://cookie.engineer).

This website is how I think every website should be. Printable, shareable, interactive,
fun to use and semantically correct.

To be honest, take it or leave it. This is my website and I like it. I think I did a
great job at building it.


## Features

- [x] Static Website
- [x] Offline-ready Go Toolchain
- [x] Semantic HTML, CSS and JS
- [x] Works with deactivated JS
- [x] CommonMark Web Log
- [x] Dynamic Avatar Interaction
- [x] Awesome Sound Recordings
- [x] Awesome Cookie Shooter Game
- [x] Interactive Search
- [x] Encrypted CVs for enhanced privacy
- [x] Copy/Paste as CommonMark via CSS
- [x] Print Stylesheets


## Sources

- Icon Webfont created with Font Awesome Icons and [fontello](https://fontello.com).
- SVG Icons, Sounds and Graphics created by myself (@cookiengineer).
- [Highlight.js](https://highlightjs.org) embedded with `bash`, `c`, `cpp`, `css`, `diff`,
  `dockerfile`, `go`, `http`, `ini`, `javascript`, `json`, `sql`, `xml` languages.


## Usage

The Website is a completely static website. Therefore no dynamic backend language
interpreter is necessary.

However, the [Web Log](/weblog) is written in CommonMark, and the articles are rendered
to HTML via the [toolchain](/toolchain)'s Server. This server also implements a backend
that allows the [Web Log Editor](/weblog/editor.html) to read, save and remove articles.

The server automatically re-renders related URLs to HTML and the web feeds when they are
requested by the Web Browser (aka Hot Reload).


## Usage / CVs

The CVs are stored in an AES-GCM encrypted template format which uses a separate key
derived from shared passwords (which are shared only with a single person at a time).

This exists to preserve my privacy and to protect me from state-level actors that have
tried to threaten my life in the past (Hey, FSB and SVR, btw!).

The CVs are encrypted and decrypted via the toolchain's [Encrypt.go](/toolchain/cvs/Encrypt.go)
and [Decrypt.go](/toolchain/cvs/Decrypt.go). The equivalent Browser-side implementation
can be found in the [crypto/index.js](/cv/design/crypto/index.js) file.

```bash
cd /path/to/cookie.engineer/toolchain;


# Write decrypted CV to /tmp/output.cv
go run cmds/cvs/main.go decrypt "old password of already encrypted CV";

# Edit CV now
vim /tmp/output.cv;

# Write encrypted CV to ../cv/source/<derived-filename>.cv
go run cmds/cvs/main.go encrypt "new super $ecure password";
```


## License

Proprietary License.

(c) 2018-2024 Cookie Engineer (@cookiengineer).
All rights reserved.

