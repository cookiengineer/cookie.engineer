===
- date: 2020-11-30
- name: E-Mail with Postfix and Dovecot
- tags: email, server, devops
- type: legacy
===

Today I was setting up an E-Mail server for one of my projects, and I figured
that most of the relevant knowledge is widespread across the internet and very
old mailing lists of postfix that are literally older than the internet.

So here is kind of my own personal documentation on the necessary installation
and configuration procedures that are required to create a self-hosted E-Mail
server that have both encrypted SMTP and IMAP support by using Let's Encrypt's
certbot for TLS based encryption.

Additionally, E-Mail signatures are required to prevent blocking of sent E-Mails
to other E-Mail services.


## Introduction

First-off, we have to clarify some of the terminology that is required to understand
what's going on behind the scenes. E-Mail is a very old concept, and therefore
is broken on pretty much every level that tries to monkey-patch security features
on top of it.

In the context of E-Mail, there's also `STARTTLS` which is somewhat a so-called
snakeoil certificate based encryption workflow. We are going to ditch that completely,
because it basically is useless encryption. Everybody can intercept it and pretty
much no E-Mail client has real certificate pinning support, so it's totally for
verifying authenticity of the server endpoint.

Both E-Mail network protocols have literally hundreds of ways to authenticate users,
most of them require `SASL` support and have legacy databases behind them.

We are going to reuse `dovecot` to have the same auth method for both `IMAP` and
`SMTP` and we are reusing the Linux users' `/etc/passwd` so that we can create
users in a simple way and have their emails stored in their `/home/$USER/Maildir`
folders.


### The SMTP Protocol

SMTP is the Simple Mail Transfer Protocol. By default, it is unencrypted. This
protocol is managed and used by `postfix` in our scenario.

In an imaginary world where everybody gives a damn about security, we would always
use `TLS` encrypted SMTP(s) to even relay messages to other services. In the real
world, services like self-claimed privacy-aware email encryption services like
[ProtonMail](https://protonmail.com) do not even have smtps support and only
accept messages via unencrypted connections.

In the context of postfix we are going to talk about inbound connections (other
clients connecting to us via `imapd`) and outbound connections (we connecting to
another server via `imap`).

Relaying messages means that some other Mail Transport Agent is connecting to
us and wants us to send E-Mails to another domain - and we usually don't want
do that because a lot of spammers out there abuse this.

You can manually list the authentication methods by connecting to an SMTP server
via port `25` (by using `telnet`) or via port `465` (by using `openssl`).

```bash
# Unencrypted connection to postfix server
# manually typing "EHLO example.com"

$ telnet example.com 25

Trying 1.3.3.7...
Connected to example.com.
Escape character is '^]'.
220 example ESMTP Postfix

EHLO example.com

# Available SMTP commands
250-example.com
250-PIPELINING
250-SIZE 10240000
250-VRFY
250-ETRN
250-STARTTLS
250-ENHANCEDSTATUSCODES
250-8BITMIME
250-DSN
250-SMTPUTF8
250 CHUNKING
```

```bash
# TLS-encrypted connection to postfix server
# manually typing EHLO example.com

$ openssl s_client -crlf -connect example.com:465

CONNECTED(00000003)
depth=2 O = Digital Signature Trust Co., CN = DST Root CA X3
verify return:1
depth=1 C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
verify return:1
depth=0 CN = example.com
verify return:1
---
Certificate chain
0 s:CN = example.com
i:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
1 s:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
i:O = Digital Signature Trust Co., CN = DST Root CA X3
---
Server certificate
---
(... bunch of TLS-related stuff ...)
---
read R BLOCK
220 example.com ESMTP Postfix

EHLO example.com

250-example.com
250-PIPELINING
250-SIZE 10240000
250-VRFY
250-ETRN
250-AUTH PLAIN LOGIN
250-ENHANCEDSTATUSCODES
250-8BITMIME
250-DSN
250-SMTPUTF8
250 CHUNKING
```


### The IMAP Protocol

IMAP is the Internet Message Access Protocol. By default, it is unencrypted. This
protocol is managed and used by `dovecot` in our scenario.

The IMAP daemon usually has support for multiple storage formats. This storage
format has to be identically configured in both `postfix` (our MTA) and `dovecot`
(our IMAP daemon). In both cases we are going to use the `Maildir` format.

In the context of dovecot we are going to disallow unencrypted usage of the IMAP
protocol, which means that port `143` will not be used, and we are going to encrypt
all connections via TLS on port `993`.

We don't want our users to be potentially intercepted while they download E-Mails.

You can manually authenticate and list the inbox by connecting to an IMAP server
via port `993` (by using `openssl`).

```bash
# TLS-encrypted connection to dovecot server

$ openssl s_client -crlf -connect example.com:993

CONNECTED(00000003)
depth=2 O = Digital Signature Trust Co., CN = DST Root CA X3
verify return:1
depth=1 C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
verify return:1
depth=0 CN = example.com
verify return:1
---
Certificate chain
0 s:CN = example.com
i:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
1 s:C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
i:O = Digital Signature Trust Co., CN = DST Root CA X3
---
Server certificate
---
(... bunch of TLS-related stuff ...)
---
read R BLOCK
* OK [CAPABILITY IMAP4rev1 SASL-IR LOGIN-REFERRALS ID ENABLE IDLE LITERAL+ AUTH=PLAIN AUTH=LOGIN] Dovecot ready.
```


### DMARC

DMARC means Domain-based Message Authentication, Reporting and Conformance and is an
authentication protocol that extends DKIM and SPF.

In order to make it work, you must have to add a `TXT` record to your domain. If
your domain doesn't support `DKIM` and `DMARC` entries, the sent emails are very
likely classified as spam by other providers.

DMARC as a guideline is hosted at [dmarc.org](https://dmarc.org) and specified as
[RFC7489](https://tools.ietf.org/html/rfc7489), and its goals is to define the
reporting methods for authentication failures, and wants to prevent phishing via
spoofed E-Mails.

The idea is that the `_dmarc` subdomain entry includes URIs for receiving
forensic reports, so that e.g. the administrator can get notified of these
incidents.

Additionally, the policy should be reflected to describe what happens when an
unauthenticated user is sending E-Mails via our server.

- `p=none` means that there is no action taken regarding the delivery of messages.
- `p=quarantine` means that unverified messages are quarantined inside the `Spam` folder.
- `p=reject` means that no unverified messages can be received by a receiving server, and they should be immediately deleted.

In a minimalistic scenario where we don't want to deal with unnecessary reports
(everybody can see this, so we would get spam there, too), a `_dmarc.example.com`
TXT entry looks like this:

```
$ dig TXT _dmarc.example.com

;; ANSWER SECTION:

_dmarc.example.com.	3600	IN	TXT	"v=DMARC1; p=quarantine"
```


### DKIM

DKIM is the DomainKeys Identified Mail authentication method. It is an authentication
method that uses a digital signature attached to every E-Mail sent by an MTA. This
signature uses a local RSA-based key, and the public key is published as a DNS record,
so that the receiving MTAs can see the public key via DNS lookup.

In order to make it work, you must have to add a `TXT` record to your domain. If
your domain doesn't support `DKIM` and `DMARC` entries, the sent emails are very
likely classified as spam by other providers.

The idea behind the concept is that a client receives an E-Mail. After reading through
the E-Mail, the MTA can look for the public key to verify that this E-Mail was sent
indeed by the mentioned domain's server.

As `DKIM` allows multiple public keys, they are identified via a unique name. This
identifier is called `selector` in the context of `opendkim`.

```bash
# mail is the unique identifier of the key where PUBLIC_KEY
# has the contents of the (later) generated mail.txt file

$ dig TXT mail._domainkey.example.com

;; ANSWER SECTION:
mail._domainkey.example.com. 3600	IN	TXT	"v=DKIM1; k=rsa; s=email; p=$PUBLIC_KEY"
```


### SPF

SPF is the Sender Policy Framework which is a mechanism for a receiving MTA to identify
which hosts and IP addresses are allowed to send E-Mails via a given domain. Similar
to `DKIM` it is published (and looked up) using `TXT` records of a specific domain.

SPF is specified in [RFC 7208](https://tools.ietf.org/html/rfc7208).

The `TXT` record of a domain contains pattern matching mechanisms that are executed and
validated by the receiving MTA.

An example allowing only E-mails sent from an `MX` record of a specific domain usually
only contains `mx -all`, stating that the server will deny all other emails being sent
through it (which is probably the case for most email servers these days, but keep in
mind that an MTA can relay messages).

```bash
$ dig TXT example.com

;; ANSWER SECTION:
example.com.		3190	IN	TXT	"v=spf1 mx -all"
```


### Mailbox Format


## Installation


## Configuration

