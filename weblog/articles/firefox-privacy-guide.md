===
- date: 2025-08-20
- name: Firefox Privacy Guide
- tags: privacy, security, desktop
- type: software
- crux: Best Practices for Firefox to make it respect your Privacy.
===


Changing settings can be cumbersome, especially in Firefox where the Normandy Service
really really likes to change privacy enhancing settings back, remotely, because an admin
at Mozilla decided to do so.

In order to find your Firefox Profile, visit `about:support`, then under the headline
`Application Basics` next to `Profile Directory` you can click on `Open Directory`.
This will open the file browser showing your Firefox Profile.

In your Firefox Profile, you'll have to create a `user.js` file. This file is a simple
line-based command-styled configuration file that will not be changed if Firefox gets
updated or the Normandy service does funny stuff again.


## Disable Telemetry Service

Firefox has a Telemetry service enabled by default. These are the settings to deactivate it.

```js
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.sessions.current.clean", true);
user_pref("datareporting.sessions.current.activeTicks", 0);
user_pref("datareporting.healthreport.service.enabled", false);
```


## Disable Normandy Services

Normandy is the Mozilla Service that will remote-install Extensions on your system,
and change your local settings if a Mozilla Salesman decided it's good for you.

Remember when Mozilla broke Adblockers remotely and disabled them?
Yeah, that was the Normandy service.

```js
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "http://0.0.0.0/normandy/v1");
user_pref("app.shield.optoutstudies.enabled", false);
```


## Disable Crash Reporter

Crash Reports contain Cookie data, Session data and other things that are nobody's business.

```js
user_pref("breakpad.reportURL", "http://0.0.0.0/breakpad/report/index/");
user_pref("browser.tabs.crashReporting.sendReport", false);
```


## Disable Google Safebrowsing

Google Safebrowsing Reports contain Cookie data, Session data and other things that are nobody's business.

```js
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.downloads.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.url", "");
user_pref("browser.safebrowsing.provider.google.updateURL", "http://0.0.0.0/safebrowsing/downloads?client=SAFEBROWSING_ID&appver=%MAJOR_VERSION%&pver=2.2&key=%GOOGLE_SAFEBROWSING_API_KEY%");
user_pref("browser.safebrowsing.provider.google.gethashURL", "http://0.0.0.0/safebrowsing/gethash?client=SAFEBROWSING_ID&appver=%MAJOR_VERSION%&pver=2.2");
user_pref("browser.safebrowsing.provider.mozilla.gethashURL", "http://0.0.0.0/safebrowsing/gethash?client=SAFEBROWSING_ID&appver=%MAJOR_VERSION%&pver=2.2");
user_pref("browser.safebrowsing.provider.mozilla.updateURL", "");
```


## Disable URL Bar Suggestions

URL Search Bar suggestions will automatically predict what you're typing, even when you're just
looking for an already visited (or bookmarked) page. That's not okay either.

```js
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.sponsoredTopSites", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.searches", false);
```


## Disable Firefox Pocket

We all know Firefox Pocket, which nobody asked for and nobody wanted.

```js
user_pref("extensions.pocket.api", "http://0.0.0.0/pocket");
user_pref("extensions.pocket.enabled", false);
user_pref("extensions.pocket.showHome", false);
user_pref("browser.newtabpage.activity-stream.discoverystream.saveToPocketCard.enabled", false);
```


## Disable Network Prefetching

Some websites contain `<meta rel="dns-prefetch">` elements or the new
`<a ping="tracker.tld">...</a>` attribute on HTML links. This will deactivate
them as good as possible. Make sure you install uBlock Origin as an Extension
to prevent further abuse.

```js
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.predictor.enabled", false);
user_pref("network.predictor.enable-prefetch", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
```


## Disable Geolocation Services

Firefox uses `geoclue` as a library, which is usually a system-provided package
or bundled library. But when that fails they'll of course track your location
with their own geolocation API on every restart of the Browser. This fixes that.

```js
user_pref("geo.enabled", false);
user_pref("geo.provider.network.url", "http://0.0.0.0/geolocation/v1/geolocate?key=%GOOGLE_LOCATION_SERVICE_API_KEY%");
user_pref("geo.provider.use_geoclue", false);
```


## Disable Captive Portal Detector

This might break Public Wi-Fis, because the captive portal service pings that URL
every couple seconds to find out whether you were redirected to the Wi-Fi router's
captive portal, e.g. the ones where you have to click on "Sell my firstborn child"
first to use the internet.

If you're using public Wi-Fis regularly and can't avoid this, I'd recommend to set
the `captivedetect.canonicalURL` to the same one as the one that's configured in
your Network Manager's settings. You can make the Feds chase wrong exploits by setting
this to another distribution's default value, or at least slow them down quite a bit.

```js
user_pref("network.captive-portal-service.enabled", false);
user_pref("captivedetect.canonicalURL", "http://detectportal.firefox.com/canonical.html");
```

| Distribution    | Network Connection Test URL                                 |
|:----------------|:------------------------------------------------------------|
| ArchLinux       | `http://ping.archlinux.org/nm-check.txt`                    |
| Debian          | `http://network-test.debian.org/nm`                         |
| RedHat          | `http://static.redhat.com/test/rhel-networkmanager.txt`     |
| Ubuntu          | `http://connectivity-check.ubuntu.com`                      |
| macOS           | `http://www.apple.com/library/test/success.html`            |
| macOSX or later | `http://captive.apple.com/hotspot-detect.html`              |
| Windows 8       | `http://www.msftncsi.com/ncsi.txt`                          |
| Windows 10      | `http://www.msftconnecttest.com/connecttest.txt`            |
| Google Chrome   | `http://connectivitycheck.gstatic.com/generate_204`         |
| Mozilla Firefox | `http://detectportal.firefox.com/canonical.html`            |
| Microsoft Edge  | `http://edge-http.microsoft.com/captiveportal/generate_204` |


## Disable TLS OCSP Checks

OCSP will receive copies of the server's TLS certificates, which means the
google-provided server will know what encrypted websites you were browsing
to. This fixes that.

```js
user_pref("security.OCSP.enabled", 0);
user_pref("security.OCSP.required", false);
user_pref("security.ssl.enable_ocsp_must_staple", false);
user_pref("security.ssl.enable_ocsp_stapling", false);
```


## Disable Privacy-Compromising DOM APIs

I don't know what is going on at the WHATWG, but these APIs and DOM features
leak personal information about your system

```js
// WebRTC Peer Connections leak private IP
user_pref("media.peerconnection.enabled", false);

// WebGL is used for Fingerprinting
user_pref("webgl.disabled", true);
user_pref("webgl.enable-webgl2", false);
user_pref("webgl.force-enabled", false);

// DOM Push Notifications
user_pref("dom.push.connection.enabled", false);
user_pref("dom.push.enabled", false);
user_pref("dom.push.serverURL", "ws://0.0.0.0/push-services");

// DOM Events
user_pref("dom.event.clipboardevents.enabled", false);
user_pref("dom.event.contextmenu.enabled", false);
user_pref("dom.battery.enabled", false);
user_pref("dom.gamepad.enabled", false);
user_pref("dom.gamepad.extensions.enabled", false);
user_pref("beacon.enabled", false);
```


## Disable New Tab Page Trackers

The New Page honestly is pretty much the worst in terms of Privacy and GDPR
violations. I have no idea how Mozilla hasn't been sued into oblivion yet.

Advertisers, Trackers, Social Feeds, pretty much everything will still be
included and rendererd and called to every time you open a `New Tab` page,
even if you set all settings to the most privacy-respecting ones. These
settings will fix that.

```js
// Start Page
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.preonboarding.enabled", false);
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");


// Tracker Feeds
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.system.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.system.showSponsoredCheckboxes", false);

user_pref("browser.newtabpage.activity-stream.feeds.adsfeeds", false);
user_pref("browser.newtabpage.activity-stream.feeds.discoverystreamfeed", false);
user_pref("browser.newtabpage.activity-stream.feeds.inferredpersonalizationfeed", false);
user_pref("browser.newtabpage.activity-stream.feeds.places", false);
user_pref("browser.newtabpage.activity-stream.feeds.recommendationprovider", false);
user_pref("browser.newtabpage.activity-stream.feeds.system.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.system.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.system.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.trendingsearchfeed", false);
user_pref("browser.newtabpage.activity-stream.feeds.wallpaperfeed", false);
user_pref("browser.newtabpage.activity-stream.feeds.weatherfeed", false);


user_pref("services.sync.prefs.sync.browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("services.sync.prefs.sync.browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("services.sync.prefs.sync.browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsored", false);
user_pref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsoredTopSites", false);
```


## Fingerprinting and Cookies

This is my paranoia calling, but I don't want a Browser History preserved
on my system, especially not on my Laptop that I might lose (or get stolen)
at any time that I cannot predict.

```js
user_pref("privacy.resistFingerprinting", true);
user_pref("network.cookie.cookieBehavior", 1); // 1 = block 3rd party

user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.downloads", true);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.history", true);
user_pref("privacy.clearOnShutdown.sessions", true);
```


## Privacy Enhancing Extensions

- Install [uBlock Origin](https://github.com/gorhill/uBlock) to prevent websites from tracking you.
- Install [LocalCDN](https://codeberg.org/nobody/LocalCDN) to prevent CDNs from tracking you.


## Firejail

For further Privacy on your system, I recommend the use of [firejail](https://github.com/netblue30/firejail)
because it's a good enough approach if you cannot use advanced App Sandboxes like QubesOS
would provide.

Firejail will allow you to use Firefox essentially inside a sandbox, where it has access
to a fake filesystem layer and can only reach the folders and files on your filesystem
that you explicitely allowed it to access.

In my case, Firefox has only access to the `~/Downloads` folder and nothing else.

