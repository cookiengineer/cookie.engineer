===
- date: 2019-12-31
- name: Implementer's Guide to SOCKS
- tags: socks, network, node.js
- type: software, legacy
===

Yesterday I was verifying that the SOCKS test suite of [Tholian Stealth](https://github.com/tholian-network/stealth)
is working.

The problem with SOCKS in a nutshell is that it is not as well
documented as someone might think.

Most people are even unaware of the role that a SOCKS proxy plays
in between network connections and therefore don't know what exactly
a SOCKS proxy can or cannot do in regards to blocking ads and malicious
domains.

So I thought that a reference-class article for SOCKS4 and SOCKS5
would be nice, documenting its quirks and common pitfalls while
implementing those protocols.

For the implementation we're going to build in this article,
we only need plain node.js and its `net` core stack. The
implementation will be peer-to-peer, which means it can be used
for both the client-side and server-side whereas both sides are
implemented in node.js for the sake of simplicity.


## Introduction

First off, you have to know that the `SOCKS` protocol is specified as
[RFC1929](https://tools.ietf.org/html/rfc1929) and didn't change since
`1996` so it's somewhat safe to assume that this is the final version
of the network protocol.

The SOCKS protocol in general and its role is pretty much what telephone
operators did in the past. A client connects to the SOCKS proxy and
requests to connect to a specific target. The proxy tries to connect
to the target, and if it succeeds reaches through the connection to the
client.

```chat
- Client - Please let me connect to IP 1.2.3.4.
- Proxy  - Trying to connect... please hold the line ...
- Proxy  - Here's the connection handle, any further data will be dispatched through automatically.
```

```chat
- Client - Please let me connect to IP 1.2.3.4.
- Proxy  - Trying to connect... please hold the line ...
- Proxy  - Sorry, the given target is not reachable. Please try again later.
- Proxy  - *hangs off the phone* Beep Beep Beep.
```

As both `SOCKS4` and `SOCKS4a` were proprietary protocols, they didn't
have any RFC. `SOCKS5` is referring a lot the `SOCKS4` protocol and
its featureset, so reading the RFC is quite complicated if you don't
know what the older protocol versions actually did feature-wise.

Usually though, most clients and servers that claim to support SOCKS5
actually only support the `user` and `password` authentication, not
the `IPv6` or `DNS/UDP` related features that come with it.

This implementation will focus mostly on the `IPv4` and `IPv6`
differences and will - for the sake of simplicity - only support `TCP`
based connections.


The `SOCKS4` featureset:

- connects to `IPv4` (TCP)

The `SOCKS4a` featureset:

- connects to `IPv4` (TCP)
- connects to `domain` (TCP)
- authentication via `user` is broken in practice (no password)

The `SOCKS5` featureset:

- connects to `IPv4` (TCP and UDP)
- connects to `IPv6` (TCP and UDP)
- connects to `domain` (TCP)
- authentication via `user` and `password`


## SOCKS Server

## Connection Request

## Connection Response

## SOCKS Framing

## Authentication

## Handling Connections

