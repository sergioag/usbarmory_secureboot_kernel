This repository contains scripts for building a Linux kernel for the USB Armory mkII, subject
to the following conditions:

- Trusted Boot is enabled
- Trusted Boot keys are available
- Device is already configured for trusted boot

The main difference between this procedure and the "official" one is that this enforces module
signature verification. This makes sense because otherwise we would load untrusted code at
kernel-level.

Pre-Requisites
==============

To be written (same as usbarmory-debian-base_image)


How to build
============

To be written