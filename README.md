This repository contains scripts for building a Linux kernel for the USB Armory mkII, subject
to the following conditions:

- Secure Boot is enabled
- Secure Boot keys are available
- Device is already configured for secure boot

The main difference between this procedure and the "official" one is that this enforces module
signature verification. This makes sense because otherwise we would load untrusted code at
kernel-level.

Pre-Requisites
==============

First go through the [Pre-Requisites for the USB Armory Debian base image](https://github.com/f-secure-foundry/usbarmory-debian-base_image#pre-requisites).

Second, configure Secure Boot as specified in [Secure-boot (MkII)](https://github.com/f-secure-foundry/usbarmory/wiki/Secure-boot-(Mk-II)).

Finally, make sure you have the following environment variables set before continuing:
- KEYS_PATH: The directory where the keys were created (see the second pre-requisite).
- USBARMORY_GIT: The path for a clone of the [usbarmory Git repository](https://github.com/f-secure-foundry/usbarmory).

A small step is required in the KEYS_PATH directory. Go to that directory and type:
```
cat usbarmory.crt usbarmory.key > usbarmory_chain.pem
```

How to build
============

After going through all the pre-requisites and having the required environment variables, just execute:

make

Additional parameters include:
- BOOT: eMMC or uSD. Defaults to eMMC. This is the default boot device for u-Boot.
- IMX: imx6ull or imx6ul. Defaults to imx6ull and only tested on this one, since I don't have the other. Should work though.

After the build finishes you will have a DEB package in this directory, named something like `linux-image-4.19-usbarmory-mark-two_5.4.25-0_armhf.deb`. To install it, in your USBArmory, run:
```
dpkg --install linux-image-4.19-usbarmory-mark-two_5.4.25-0_armhf.deb
```
And then reboot. If everything goes ok, it should boot properly.
