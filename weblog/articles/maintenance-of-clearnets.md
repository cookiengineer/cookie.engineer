===
- date: 2019-04-26
- name: Maintenance of Clearnets
- tags: privacy, security, network, web browser
- type: legacy
===


In order to understand how we can break out of Prison, we must first
understand how the Prison operates, how the Guards spot means of
Breakouts (Tools, Weapons), how they rotate their watch shifts; and
how they generally behave and react to things that are going on inside
the Prison.

The same applies for a Breakout of the Clearnet. In general, Internet
Service Providers (ISPs) use a couple of techniques in parallel to make
your experience of the Internet as bad as possible.

When we talk about how they operate, we must assume that the ISP is
always the Man in the Middle (MITM) and can read, understand and
manipulate any unencrypted data that is transferred between you, Alice,
and Bob, the server that you're communicating to.


### Operating System

In general I'd recommend to use an up-to-date Linux Distribution for
means of access of the internet. Network behaviour on MacOS and Windows
cannot be guaranteed anyhow; therefore it is heavily disrecommended
if you're serious about your Privacy.

And you should be, because Governments have lots of Exploits already
available that are automatically installed on your Computer; no matter
if you're the bad guy or a nice guy. They don't care.


### General Hints for Dealing with Customs

Always use an up-to-date Linux Distribution (like Arch Linux), always
encrypt all your partitions, always use a small nano-USB-thumbdrive as
a crypto unlock key file in combination with a password. They also come
in the form of a wedding ring or necklace. If you travel with a dog or
cat, that's even better.

Always power down your Laptop; and remove the thumbdrive before walking
through Customs at the Country Border.

In my case, I also only use Libreboot-compatible Hardware; which means
it is a bit out of date by performance standards... but with the ongoing
never-ending shitstorm about Bugs, Backdoors and Exploits in more modern
Intel processors I'm quite happy with that decision.

You'll be amazed how often Customs will ask you whether your Laptop is
broken or not when they cannot boot it up ... which should be a hint
that they unsuccessfully tried to invade your Privacy, and tried to
install Spyware on your Computer without your permission.


## The OSI Model

In order to understand how the Prison operates, you have to understand
how the internet and its underlying network infrastructure works.

When talking about the Web, most people understand it as `E-Mail` and
`Websites`, maybe even `VPN` but not nerdy things like IRC or ICMP.

Therefore this Guide will focus on the problems of `TCP` and `UDP`
based internet connections.

When talking about Network Protocols, they are divided in different
OSI layers which each add different capabilities to the network protocol.
These days the lines in between blurr up a little, but the basic
principles are the same.

The OSI Layers that are interesting to us are:

1. The `Physical Layer` connects machines via a transmission medium, like a network cable (or Wi-Fi or radio).
2. The `Data Link Layer` links specific machines together, which are addressed via `MAC addresses` (also known as hardware addresses).
3. The `Network Layer` links specific network sockets together, which are addressed via `IP addresses`.
4. The `Transport Layer` defines the network socket data frames and its contents and mechanics (like `TCP` or `UDP`).
6. The `Session Layer` defines ids and temporary sessions. In our case this is only interesting for the `SOCKS` proxy routing protocol.
7. The `Presentation Layer` defines encryption/decryption, for example an `SSL` or `TLS` session.
8. The `Application Layer` is the high-level network protocol that Applications work with, for example `HTTP/HTTPS` or `SMTP/IMAP`.

Usually when network administrators talk about broken infrastructure,
they tend to talk about which OSI layer is affected by the Bug. This
helps them to identify the Bug more quickly and to trace down the
broken Hardware or Firmware/Software.

A broken OSI Layer 1 means that a Network Hub or a Network Cable is
broken. When OSI Layer 2 is affected, it concludes that a Network
Switch or a piece of software (Firewall) that knows things about MAC
and IP relationships is not working. When OSI Layer 3 is broken, it
usually means that a Router or Gateway doesn't work as intended.

This goes on and on for each OSI Layer, in our case only these three
layers are generally interesting when breaking out of the Clearnet
(Censored Internet).


## Blocking Techniques

There are several ways on what is actually done in order to block as
much "unwanted" Network Traffic as possible. Most of the time, only
one of the following Hurdles is actually necessary; but most
Governments have multiple ones in place to achieve maximum control
of their Zombie inhabitants.


### MAC Address Blocking (Layer 2)

In general, network connections are automatically tagged by ISPs. If
they can see your MAC address, they'll also identify you by your MAC
address. Many "Free Wi-Fi" Router Firmwares actually report the
contents of their Network Address Translation Table (NAT) and therefore
the MAC and IP addresses back to the ISPs.

That's why it's important to randomize your MAC address not only for
Wi-Fi connections, but also for cable connections.

```bash
# Assumes enp3s0 is your cable connection
sudo macchanger -r enp3s0;

# Assumes wlp3s0 is your wifi connection
sudo macchanger -r wlp3s0;
```

Deactivate all Wi-Fi autoconnect features in order to prevent being
traceable by the Wi-Fi networks that your Wi-Fi card tries to ping
when being disconnected.

In Network Manager Profiles, you can add these settings to your Connection
that is located in `/etc/NetworkManager/system-connections/*.nmconnection`.

Edit the file as `root` (not via `sudo`) and keep the `chmod` of the
file identical. Otherwise NetworkManager will forget the Connection
Settings and mess things up.

```ini
[connection]
id=Example-WiFi
(...)
type=wifi
autoconnect=false

[wifi]
mac-address=00:01:02:03:04:05; generated via macchanger -sr wlp3s0
[ipv4]
dhcp-send-hostname=false

[ipv6]
dhcp-send-hostname=false
```


### TCP RST Injection (Layer 4)

TCP is a very nice Network Protocol, but it has an essential flaw which
is called Fragmentation.

The underlying TCP data frame starts with a so-called `FIN` flag, which
represents whether or not the data frame is `finished` and can be
processed by the software that receives it. When the `FIN` flag is set
to `0`, it means that the software will continue to wait until new data
arrives; and try to put the upcoming chunks together when they arrive;
into this big, locally maintained history of past uncomplete chunks.

Additionally, TCP has a feature called `RST` which is basically a message
that says `Hold on ... I haven't forgot about you, I just need a while ...`
which means that the software will wait for the next data frame, and
usually it does so longer than it would without by resetting the local
timeout.

For example, when a software would time out after 30 seconds of waiting,
the only thing an ISP would have to do is sending another `RST` packet
every 30 seconds and manipulate all incoming TCP frames to `FIN=0` to
slow down the software dramatically.

Literally this is what happens on throttled "Flatrate" 3G/4G connections.

The bandwidth of HSPA+ or LTE is too fast to send just 4kiB/s (note that
kiBiBit is not kiloBit is not kiloByte), so ISPs use this technique in
order to slow it down to the minimum speeds until all software (read
as: Web Browsers) break. Literally everything else like IMAP-based
email will break all the time and throw an absurd amount of errors.


### VPN Connections (Layer 2/4/7)

What is important here is that plain VPN connections that are TCP-based
are also affected by the TCP `FIN` and `RST` flaw and therefore cannot
be relied on.

VPN connections are auto-tagged and auto-throttled when they do connect
to certain networks or IP ranges in specific geolocation areas (e.g.
Sweden or Switzerland are off limits, usually).

Additionally popular VPN providers usually are auto-blocked via an
IP-based blocklist which means that everything above Layer 2 will not
work and they're basically just a big waste of money.


### SOCKS Proxies (Layer 5)

SOCKS Proxies are a different story and they are hard to explain as a
Network Protocol, because SOCKS itself is actually not a Network Protocol
but rather something like a Connection Creation Protocol.

What SOCKS does is basically have a `Client > Proxy > Server` connection,
whereas the Proxy itself can be abused for Blocking Purposes or as a
connection handler that sits in the middle.

A SOCKS Proxy can be imagined as the Telephone Operator Lady that you
could call when you had no idea what the Number of the person was you
were trying to call.

The function of a SOCKS Proxy is similar in the sense that it does the
connecting and forwarding part when only the Proxy is reachable, but
not the Server that you're trying to communicate to.

Anyhow SOCKS is unencrypted (below Layer 6) and therefore can be easily
manipulated, and connections can be blocked as well. That's why it's
just a matter of time before the new server pool behind projects like
`shadowsocks` won't work anymore.


### SSL/TLS Certificate Injection (Layer 6)

Most people assume that when there's the Secure Icon in the Browser
that it means the connection is secure, private, and safe.

Guess what, you're wrong.

SSL was broken on uncountable accounts (Certificate Nulling, Sony Root
Cert Leak, Weak Elliptic Curves, Heartbleed, Dragonblood and what not),
and the new encryption protocol is called Transport Layer Security (TLS).

But, TLS is also broken up until and including TLS 1.2. With the
[letsencrypt](https://letsencrypt.org) initiative the usage of the `SNI`
field got so popular that now ISPs are meanwhile regularly abusing it
to infiltrate encrypted connections.

The `SNI` stands for `Server Name Identification` which basically allows
a web hosting provider to have a single server that has multiple domains
pointing to it; and that its software can deliver the correct encryption
certificate for the currently requested domain.

But, as you might have guessed, `SNI` before TLS 1.3 (which isn't rolled
out yet) was transferred unencrypted and lead to plain-old unencrypted DNS
request for that very domain. As the DNS protocol is unencrypted, it
lead to ISPs being able to manipulate that result; and therefore legitimize
otherwise invalid certificates.

So, always check for TLS 1.3 and above; and assume that TLS 1.2 and
below are insecure. As TLS 1.2 and before is not really deprecated it
will continue to help exploit users for a long time to come and it will
take an even longer time to upgrade all those legacy websites running
on legacy software.

The only Browser that currently fixes this issue is the
[Stealth](https://github.com/cookiengineer/stealth) Browser. Yeah yeah,
I know, shameless plug, but it's just so that you actively keep in mind
that other Browsers aren't as secure as they claim to be; even when not
talking about their always-on-not-actually-deactivateable tracking.


### DNS Time-To-Live Manipulation (Layer 7)

Even when your network connection is encrypted, your network might be
compromised. Your Computer doesn't understand what `cookie.engineer`
or `github.com` means and needs a translation back to the underlying
Layer 2 with an `IP address` that represents that domain.

In order to do so, there's `DNS`. Probably one of the oldest Network
Protocols designed by ARPA. The important part here is that the `DNS`
Network Protocol itself is unencrypted and that ISPs therefore abuse
and manipulate it.

Imagine you're an ISP and you want customer data insights about how
much you can charge for an unlimited YouTube connection (yes, this is
currently the case even in Germany, how's that for Net Neutrality).

In that case you need to know how many of your customers are surfing
how often on YouTube (or the Google Video CDN domains).

What you, as an ISP, can do is pretty simple. The DNS Protocol has a
so-called Time-To-Live field inside it, which means that the receiving
Computer should forget about the Domain in `X seconds` (quite literally)
and Computers will gladly do so.

So, if you visit `searx.me`, the Browser does a DNS request, then
remembers the IP address, and only then connect to the Server via TCP
(or HTTP/S). But if the `TTL` field in the DNS request had the value
`0`, it will immediately forget about it... which means that when you
loaded the page and you click a single link (that also is on `searx.me`)
the Browser will end up doing a DNS request, again.

And this continues, again and again... again and again. So even if the
ISPs don't know the exact data that was transferred, they can basically
log all the domain requests and times (and bandwidths of that internet
connection) and then correlate back with their own downloaded versions
of the website.

This is literally how they know you've visited that exact Google Search
Page already and how they know you've visited this particular Web Page
on a specific Website... because usually, each Web Page has a unique
amount of JavaScripts, CSS files and other media included (which will
lead to DNS requests and is therefore trackable by ISPs).


### HTTP Payload Manipulation (Layer 7)

An also quite popular mechanism of ISPs to infiltrate your connection
is a so-called HTTP Downgrade Attack that works usually in Firefox or
(not-so-recent) Chrome versions.

An HTTP Downgrade Attack is pretty simple. The Web Browser has a serious
flaw: It requests websites first via `HTTP` and only then (optionally)
upgrades the connection to `HTTPS`.

ISPs manipulate the very first request, and basically remove the
`Connection: Upgrade` instructions inside the Response in order to
force the Web Browser into thinking that the Webserver only supports
unencrypted connections.

This method is used at least in North Korea, Myanmar, Thailand and
China (judging from personal travel experience). I've also seen it in
some networks in eastern parts of Ukraine, but I'm not sure whether
or not that was ISP or Public Wi-Fi specific.

Nevertheless this is the reason why [HTTPS Everywhere](https://addons.mozilla.org/en-US/firefox/addon/https-everywhere/)
should be mandatory for every Web Browser installation.


## Breakout of Clearnets

Now that we know how the Prison operates and how the Prison Guards
rotate their watch shifts and where they stand guard, we can now
discuss the Tools we need in order to breakout of the Prison.

The follow-up article is [Breakout of Clearnets](./breakout-of-clearnets.html)
and writes exactly about that.

