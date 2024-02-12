===
- date: 2022-07-01
- name: Nokia 800 Tough
- tags: feature-phone, kaios
- type: software, legacy
- crux: How to live with a banana phone (that uses KaiOS)
===


Last week I decided to get a banana phone. No idea why, no specific reason,
just dumb curiosity to have something to fiddle around with.

After skimming through the [KaiOS Devices](https://www.kaiostech.com/explore/devices/),
I decided that the Nokia 800 Tough is probably the best phone for me, as
I'm pretty clumsy and constantly let phones fall to the ground by accident.

This write-up will be my personal notes, more in the sense of a Quickstart
Guide than anything else... as information on how to do things with KaiOS
is pretty chaotically spread around in some comments on some unfindable
support thread somewhere on a random website in the South-Asian internet.


## Firmware

The firmware with the version identifier `v12` seems to be standard among
a lot of countries/target areas. But the `v20` is the one that still allows
to sideload apps (more on that later), whereas the `v30` is more locked down
and blocks the `OmniSD` app.


## Debug Mode

The debug mode can be activated quite easily. Enter the GSM code `*#*#33284#*#*`,
which is basically typing in `*#*#debug#*#*` as the keyboard is a T9 one.

When the debug mode is activated, you can see a little bug icon at the top of the
screen, and `adb devices` on your connected computer should show up the device
as being connected. Then we can also use `adb shell` to get an overview of
how the system looks like.

```bash
[$] adb devices;
* daemon not running; starting now at tcp:5037
* daemon started successfully
List of devices attached
c6801cad	device
```

## Filesystem

The filesystem has `5` partitions, and it looks very familiar to an Android device:

- `/system` and contains the operating system, including preinstalled web apps.
- `/data` and contains all user data, including installed apps.
- `/cache`.
- `/persist`.
- `/modem` and contains the modem firmware.

The device also has an old `Linux 3.10.49` kernel running, which might come handy later
in case we need a user-privilege escalation exploit (and if the rooting instructions fail).

```bash
[$] adb shell;
shell@Nokia 800 Tough:/ $ mount;
(...)
/dev/block/bootdevice/by-name/system /system ext4 ro,seclabel,relatime,discard,data=ordered 0 0
/dev/block/bootdevice/by-name/userdata /data ext4 rw,seclabel,nosuid,nodev,noatime,discard,noauto_da_alloc,data=ordered 0 0
/dev/block/bootdevice/by-name/cache /cache ext4 rw,seclabel,nosuid,nodev,relatime,data=ordered 0 0
/dev/block/bootdevice/by-name/persist /persist ext4 rw,seclabel,nosuid,nodev,relatime,data=ordered 0 0
/dev/block/bootdevice/by-name/modem /firmware vfat ro,context=u:object_r:firmware_file:s0,relatime,uid=100

shell@Nokia 800 Tough:/data $ uname -a
Linux localhost 3.10.49-g58c036c69ff #1 SMP PREEMPT Sat Dec 7 08:58:31 CST 2019 armv7l
```


## KaiOS Web Apps

KaiOS is based on FirefoxOS (also known as `boot2gecko` or `b2g`). The filesystem structure
and where things are hint into that direction. If we take a look at the `/system/b2g/webapps/webapps.json`
file, we see an index of all installed web apps.

It seems that Web Apps on KaiOS are just HTML5 single-page apps that can be either hosted
locally or online. For example, the [Google Maps KaiOS Manifest](https://www.google.com/maps/preview/pwa/kaios/manifest.webapp)
is just an online manifest file that will be requested each time you open up the Google Maps
web app on KaiOS.

```bash
[$] adb shell;
shell@Nokia 800 Tough:/ $ cat /system/b2g/webapps/webapps.json;

(...)

  "snake.gaiamobile.org": {
    "origin": "app://snake.gaiamobile.org",
    "installOrigin": "app://snake.gaiamobile.org",
    "receipt": null,
    "installTime": 1575680915112,
    "updateTime": 1575680915112,
    "manifestURL": "app://snake.gaiamobile.org/manifest.webapp",
    "localId": 53,
    "appStatus": 3,
    "manifestHash": "b4922f7b1bdcc1ef762c63a2cfb819c9"
  },

(...)

shell@Nokia 800 Tough:/ $ cd /system/b2g/webapps/snake.gaiamobile.org;
shell@Nokia 800 Tough:/system/b2g/webapps/snake.gaiamobile.org $ ls -la
-rw-r--r-- root     root      1903492 2008-12-31 17:00 application.zip
-rw-r--r-- root     root          450 2008-12-31 17:00 manifest.webapp
```

Each Web App is namespaced into their own `FQDN` (fully qualified domain name), and in their
equivalent folder contain an `update.webapp` file and an `application.zip` which contains
the locally mounted assets.


## Installed KaiOS Version

The installed KaiOS version can easily be identified by taking a look at the `/system/b2g/application.ini`
or the `/system/b2g/platform.ini` file.

As we can also see, KaiOS `2.5.2` ships with Firefox `48.0.a2`, which is vulnerable to the
`buffer overflow` and use-after-free vulnerability [CVE-2020-26950](https://packetstormsecurity.com/files/166175/Firefox-MCallGetProperty-Write-Side-Effects-Use-After-Free.html).

This vulnerability even has a metasploit module available on packetstormsecurity, so this might come in handy, too.

```bash
[$] adb shell;
shell@Nokia 800 Tough:/ $ cat /system/b2g/application.ini;

[App]
Vendor=KaiOS
Name=B2G
RemotingName=b2g
Version=2.5.2
BuildID=20191207090036
ID={3c2e2abc-06d4-11e1-ac3b-374f68613e61}

[Gecko]
MinVersion=48.0a2
MaxVersion=48.0a2

[XRE]

[Crash Reporter]
Enabled=1
ServerURL=https://crash-reports.kaiostech.com/submit?id={3c2e2abc-06d4-11e1-ac3b-374f68613e61}&version=2.5.2&buildid=20191207090036
```


## Hardware Drivers

After some fiddling around, we can identify that the system uses the `Qualcomm MSM8909`
system-on-a-chip.

```bash
shell@Nokia 800 Tough:/ $ getprop ro.board.platform;
msm8909
```


## Rooting

Let's play nice and try to find some [GTFO binaries](https://gtfobins.github.io/) that
we can (ab-)use to get `root` access.

```bash
shell@Nokia 800 Tough:/ $ find /system/bin -user root -perm -4000 2> /dev/null;
(no results -_- )
```

No luck there, so `LD_PRELOAD` won't help us. The Nokia 800 Tough doesn't have a
Broadcom Wi-Fi chipset, so Broadpwn and Bluepwn won't help us either.

Time to get out the big guns. The CVE database lists a couple of potential privilege
escalation [vulnerabilities for the 3.10 kernel](https://www.cvedetails.com/vulnerability-list/vendor_id-33/product_id-47/version_id-498060/Linux-Linux-Kernel-3.10.html).

Next time we're going to use one of these exploits, because that's it for now.

