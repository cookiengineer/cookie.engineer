// Mozilla User Preferences

// DO NOT EDIT THIS FILE.
//
// If you make changes to this file while the application is running,
// the changes will be overwritten when the application exits.
//
// To change a preference value, you can either:
// - modify it via the UI (e.g. via about:config in the browser); or
// - set it within a user.js file in your profile.



// All Reporting URLs that are automatically loaded
// or send data automatically back to the Internet

user_pref("accessibility.support.url", "http://localhost");
user_pref("app.feedback.baseURL", "http://localhost");
user_pref("app.normandy.api_url", "http://localhost");
user_pref("app.normandy.shieldLearnMoreUrl", "http://localhost");
user_pref("app.productInfo.baseURL", "http://localhost");
user_pref("app.releaseNotesURL", "http://localhost");
user_pref("app.support.baseURL", "http://localhost");
user_pref("app.update.url", "http://localhost");
user_pref("app.update.url.details", "http://localhost");
user_pref("app.update.url.manual", "http://localhost");
user_pref("breakpad.reportURL", "http://localhost");
user_pref("browser.aboutHomeSnippets.updateUrl", "http://localhost");
user_pref("browser.chrome.errorReporter.infoURL", "http://localhost");
user_pref("browser.chrome.errorReporter.submitUrl", "http://localhost");
user_pref("browser.contentblocking.reportBreakage.url", "http://localhost");
user_pref("browser.dictionaries.download.url", "http://localhost");
user_pref("browser.geolocation.warning.infoURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google.advisoryURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google.gethashURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google.reportMalwareMistakeURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google.reportPhishMistakeURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google.reportURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google.updateURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google4.advisoryURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google4.dataSharingURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google4.gethashURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google4.reportURL", "http://localhost");
user_pref("browser.safebrowsing.provider.google4.updateURL", "http://localhost");
user_pref("browser.safebrowsing.provider.mozilla.gethashURL", "http://localhost");
user_pref("browser.safebrowsing.provider.mozilla.updateURL", "http://localhost");
user_pref("browser.safebrowsing.downloads.remote.url", "http://localhost");
user_pref("browser.safebrowsing.reportPhishURL", "http://localhost");
user_pref("browser.search.geoSpecificDefaults.url", "http://localhost");
user_pref("browser.search.geoip.url", "http://localhost");
user_pref("browser.search.searchEnginesURL", "http://localhost");
user_pref("browser.uitour.url", "http://localhost");
user_pref("captivedetect.canonicalURL", "http://localhost");
user_pref("datareporting.healthreport.infoURL", "http://localhost");
user_pref("datareporting.policy.firstRunURL", "http://localhost");
user_pref("devtools.devices.url", "http://localhost");
user_pref("devtools.performance.recording.ui-base-url", "http://localhost");
user_pref("devtools.remote.adb.extensionURL", "http://localhost");
user_pref("devtools.webide.templatesURL", "http://localhost");
user_pref("dom.push.serverURL", "wss://localhost");
user_pref("extensions.blocklist.detailsURL", "http://localhost");
user_pref("extensions.blocklist.itemURL", "http://localhost");
user_pref("extensions.blocklist.url", "http://localhost");
user_pref("extensions.getAddons.compatOverides.url", "http://localhost");
user_pref("extensions.getAddons.get.url", "http://localhost");
user_pref("extensions.getAddons.langpacks.url", "http://localhost");
user_pref("extensions.getAddons.link.url", "http://localhost");
user_pref("extensions.getAddons.search.browseURL", "http://localhost");
user_pref("extensions.systemAddon.update.url", "http://localhost");
user_pref("extensions.update.background.url", "http://localhost");
user_pref("extensions.update.url", "http://localhost");
user_pref("extensions.webservice.discoverURL", "http://localhost");
user_pref("gecko.handlerService.schemes.irc.0.uriTemplate", "http://localhost");
user_pref("gecko.handlerService.schemes.ircs.0.uriTemplate", "http://localhost");
user_pref("gecko.handlerService.schemes.mailto.1.uriTemplate", "http://localhost");
user_pref("gecko.handlerService.schemes.webcal.0.uriTemplate", "http://localhost");
user_pref("lightweightThemes.getMoreURL", "http://localhost");
user_pref("media.gmp-manager.url", "http://localhost");
user_pref("network.connectivity-service.IPv4.url", "http://localhost");
user_pref("network.connectivity-service.IPv6.url", "http://localhost");
user_pref("privacy.trackingprotection.introURL", "http://localhost");
user_pref("security.ssl.errorReporting.url", "http://localhost");
user_pref("services.sync.fxa.privacyURL", "http://localhost");
user_pref("services.sync.fxa.termsURL", "http://localhost");
user_pref("toolkit.crashreporter.infoURL", "http://localhost");
user_pref("toolkit.datacollection.infoURL", "http://localhost");
user_pref("webextensions.storage.sync.serverURL", "http://localhost");
user_pref("xpinstall.signatures.devInfoURL", "http://localhost");



// All Features that can potentially leak information
// to Web Sites disabled as-far-as-it-is-possible

user_pref("accessibility.browsewithcaret_shortcut.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.first_run", false);
user_pref("app.normandy.startupExperimentPrefs.dom.push.alwaysConnect", false);
user_pref("app.normandy.startupRolloutPrefs.browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.contentblocking.category", "custom");
user_pref("browser.enable_automatic_image_resizing", false);
user_pref("browser.enable_click_image_resizing", false);
user_pref("browser.laterrun.enabled", true);
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.prerender", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.search.region", "en-US");
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.search.update", false);
user_pref("browser.urlbar.timesBeforeHidingSuggestionsHint", 0);
user_pref("canvas.capturestream.enabled", false);
user_pref("canvas.filters.enabled", false);
user_pref("canvas.focusring.enabled", false);
user_pref("canvas.path.enabled", false);
user_pref("captivedetect.maxRetryCount", 0);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("devtools.memory.enabled", false);
user_pref("devtools.onboarding.telemetry.logged", true);
user_pref("devtools.performance.enabled", false);
user_pref("devtools.storage.enabled", false);
user_pref("dom.event.clipboardevents.enabled", false);
user_pref("dom.event.contextmenu.enabled", false);
user_pref("dom.event.handling-user-input-time-limit", 250);
user_pref("dom.event.highrestimestamp.enabled", false);
user_pref("dom.events.asyncClipboard", false);
user_pref("dom.ipc.plugins.reportCrashURL", false);
user_pref("extensions.blocklist.enabled", false);
user_pref("extensions.pendingOperations", false);
user_pref("extensions.pocket.enabled", false);
user_pref("extensions.ui.dictionary.hidden", true);
user_pref("extensions.ui.locale.hidden", true);
user_pref("extensions.webcompat.perform_injections", true);
user_pref("extensions.webcompat.perform_ua_overrides", true);
user_pref("image.layout_network_priority", false);
user_pref("lightweightThemes.persisted.headerURL", false);
user_pref("layout.css.background-blend-mode.enabled", false);
user_pref("layout.css.font-display.enabled", false);
user_pref("layout.css.font-loading-api.enabled", false);
user_pref("layout.css.font-variations.enabled", false);
user_pref("layout.css.overscroll-behavior.enabled", false);
user_pref("layout.css.scroll-behavior.enabled", false);
user_pref("layout.css.scroll-snap.enabled", false);
user_pref("layout.css.scrollbar-color.enabled", false);
user_pref("layout.css.scrollbar-width.enabled", false);
user_pref("layout.css.step-position-jump.enabled", false);
user_pref("layout.css.visited_links_enabled", false);
user_pref("media.autoplay.allow-extension-background-pages", false);
user_pref("media.autoplay.allow-muted", false);
user_pref("media.autoplay.ask-permission", true);
user_pref("media.autoplay.block-webaudio", true);
user_pref("media.autoplay.block-event.enabled", true);
user_pref("media.getusermedia.screensharing.enabled", false);
user_pref("media.navigator.video.enabled", false);
user_pref("media.peerconnection.enabled", false);
user_pref("media.peerconnection.ice.proxy_only", true);
user_pref("media.peerconnection.video.enabled", false);
user_pref("media.video_stats.enabled", false);
user_pref("network.cookie.cookieBehavior", 4);
user_pref("network.connectivity-service.enabled", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.tcp_keepalive.long_lived_connections", false);
user_pref("network.predictor.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("network.websocket.max-connections", 1);
user_pref("pdfjs.enabledCache.state", true);
user_pref("pdfjs.migrationVersion", 2);
user_pref("pdfjs.previousHandler.alwaysAskBeforeHandling", true);
user_pref("pdfjs.previousHandler.preferredAction", 4);
user_pref("permissions.default.camera", 2);
user_pref("permissions.default.desktop-notification", 2);
user_pref("permissions.default.geo", 2);
user_pref("permissions.default.microphone", 2);
user_pref("plugin.disable_full_page_plugin_for_types", "application/pdf");
user_pref("pref.privacy.disable_button.tracking_protection_exceptions", false);
user_pref("pref.privacy.disable_button.view_passwords", false);
user_pref("privacy.userContext.enabled", true);
user_pref("privacy.userContext.extension", "CookieAutoDelete@kennydo.com");
user_pref("privacy.userContext.longPressBehavior", 2);
user_pref("privacy.userContext.ui.enabled", true);
user_pref("reader.errors.includeURLs", false);
user_pref("security.disable_button.openDeviceManager", false);
user_pref("services.sync.prefs.sync.dom.event.contextmenu.enabled", false);
user_pref("services.sync.telemetry.maxPayloadCount", 0);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("webgl.disabled", true);



// Unique IDs reset to an empty value

user_pref("app.normandy.user_id", "");
user_pref("browser.sessionstore.upgradeBackup.latestBuildID", "");
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.startup.homepage_override.buildID", "");
user_pref("extensions.lastAppBuildId", "");
user_pref("extensions.lastAppVersion", "");
user_pref("extensions.lastPlatformVersion", "");
user_pref("extensions.ui.lastCategory", "addons://list/extension");
user_pref("toolkit.telemetry.cachedClientID", "");
user_pref("toolkit.telemetry.previousBuildID", "");



// Theming (Dark Mode and Customization)
user_pref("accessibility.typeaheadfind", true);
user_pref("accessibility.typeaheadfind.flashBar", 0);
user_pref("browser.anchor_color", "#ffffff");
user_pref("browser.display.background_color", "#303030");
user_pref("browser.display.document_color_use", 1);
user_pref("browser.display.foreground_color", "#ffffff");
user_pref("browser.display.show_loading_image_placeholder", true);
user_pref("browser.display.use_focus_colors", true);
user_pref("browser.display.use_system_colors", true);
user_pref("browser.newtabpage.pinned", "[{\"url\":\"https://searx.me\",\"label\":\"@searx\",\"searchTopSite\":true}]");
user_pref("browser.uidensity", 2);
user_pref("browser.visited_color", "#cb0f99");
user_pref("findbar.highlightAll", true);
user_pref("lightweightThemes.selectedThemeID", "firefox-compact-dark@mozilla.org");
user_pref("lightweightThemes.usedThemes", "[]");



// Dev Tools

user_pref("devtools.inspector.showUserAgentStyles", true);
user_pref("devtools.selfxss.count", 5);
user_pref("devtools.theme", "dark");
user_pref("devtools.toolbox.host", "right");
user_pref("devtools.toolbox.previousHost", "bottom");
user_pref("devtools.toolbox.sidebar.width", 800);
user_pref("devtools.toolbox.tabsOrder", "webconsole,inspector,jsdebugger,styleeditor,netmonitor");
user_pref("devtools.toolsidebar-height.inspector", 689);
user_pref("devtools.toolsidebar-width.inspector", 700);
user_pref("devtools.toolsidebar-width.inspector.splitsidebar", 250);
user_pref("devtools.webextensions.https-everywhere-eff@eff.org.enabled", true);
