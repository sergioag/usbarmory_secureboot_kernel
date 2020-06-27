
JOBS=2
LINUX_VER=5.7.6
LINUX_VER_MAJOR=${shell echo ${LINUX_VER} | cut -d '.' -f1,2}
KBUILD_BUILD_USER=usbarmory
KBUILD_BUILD_HOST=f-secure-foundry
LOCALVERSION=-0
UBOOT_VER=2020.04

USBARMORY_REPO=https://raw.githubusercontent.com/f-secure-foundry/usbarmory/master
MXS_DCP_REPO=https://github.com/sergioag/mxs-dcp
CAAM_KEYBLOB_REPO=https://github.com/f-secure-foundry/caam-keyblob

.DEFAULT_GOAL := all
.PHONY: check_version mxs-dcp caam-keyblob all clean
BOOT ?= eMMC
IMX ?= imx6ulz

check_version:
	@if test "${BOOT}" != "uSD" && test "${BOOT}" != eMMC; then \
		echo "invalid target, mark-two BOOT options are: uSD, eMMC"; \
		exit 1; \
	elif test "${IMX}" != "imx6ul" && test "${IMX}" != "imx6ulz"; then \
		echo "invalid target, mark-two IMX options are: imx6ul, imx6ulz"; \
		exit 1; \
	fi
	@echo "target: USB armory Trusted Boot, IMX=${IMX} BOOT=${BOOT}"

u-boot-${UBOOT_VER}.tar.bz2:
	wget ftp://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VER}.tar.bz2 -O u-boot-${UBOOT_VER}.tar.bz2
	wget ftp://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VER}.tar.bz2.sig -O u-boot-${UBOOT_VER}.tar.bz2.sig

linux-${LINUX_VER}.tar.xz:
	wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VER}.tar.xz -O linux-${LINUX_VER}.tar.xz
	wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VER}.tar.sign -O linux-${LINUX_VER}.tar.sign

mxs-dcp-master.zip: check_version
	@if test "${IMX}" = "imx6ulz"; then \
		wget ${MXS_DCP_REPO}/archive/master.zip -O mxs-dcp-master.zip && \
		unzip -o mxs-dcp-master; \
	fi

caam-keyblob-master.zip: check_version
	@if test "${IMX}" = "imx6ul"; then \
		wget ${CAAM_KEYBLOB_REPO}/archive/master.zip -O caam-keyblob-master.zip && \
		unzip -o caam-keyblob-master; \
	fi

mxs-dcp: mxs-dcp-master.zip linux-${LINUX_VER}/arch/arm/boot/zImage
	@if test "${IMX}" = "imx6ulz"; then \
		cd mxs-dcp-master && make KBUILD_BUILD_USER=${KBUILD_BUILD_USER} KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all; \
	fi

caam-keyblob: caam-keyblob-master.zip linux-${LINUX_VER}/arch/arm/boot/zImage
	@if test "${IMX}" = "imx6ul"; then \
		cd caam-keyblob-master && make KBUILD_BUILD_USER=${KBUILD_BUILD_USER} KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNEL_SRC=../linux-${LINUX_VER} -j${JOBS} all; \
	fi

u-boot-tools: u-boot-${UBOOT_VER}.tar.bz2
	gpg --verify u-boot-${UBOOT_VER}.tar.bz2.sig
	tar xf u-boot-${UBOOT_VER}.tar.bz2
	cd u-boot-${UBOOT_VER} && make distclean
	cd u-boot-${UBOOT_VER} && \
		wget ${USBARMORY_REPO}/software/u-boot/0001-ARM-mx6-add-support-for-USB-armory-Mk-II-board.patch && \
		patch -p1 < 0001-ARM-mx6-add-support-for-USB-armory-Mk-II-board.patch && \
		make usbarmory-mark-two_defconfig; \
		sed -i -e 's/CONFIG_SYS_BOOT_MODE_NORMAL=y/# CONFIG_SYS_BOOT_MODE_NORMAL is not set/' .config; \
		sed -i -e 's/# CONFIG_SYS_BOOT_MODE_VERIFIED_OPEN is not set/CONFIG_SYS_BOOT_MODE_VERIFIED_OPEN=y/' .config; \
		if test "${BOOT}" = "eMMC"; then \
			sed -i -e 's/CONFIG_SYS_BOOT_DEV_MICROSD=y/# CONFIG_SYS_BOOT_DEV_MICROSD is not set/' .config; \
			sed -i -e 's/# CONFIG_SYS_BOOT_DEV_EMMC is not set/CONFIG_SYS_BOOT_DEV_EMMC=y/' .config; \
		fi
	cd u-boot-${UBOOT_VER} && CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm make -j${JOBS} tools CONFIG_MKIMAGE_DTC_PATH="scripts/dtc/dtc"
	cd u-boot-${UBOOT_VER} && CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm make -j${JOBS} dtbs CONFIG_MKIMAGE_DTC_PATH="scripts/dtc/dtc"
	touch u-boot-tools

#sed -i -e 's/CONFIG_SYS_BOOT_MODE_NORMAL=y/# CONFIG_SYS_BOOT_MODE_NORMAL is not set/' .config
#sed -i -e 's/CONFIG_SYS_BOOT_MODE_VERIFIED_OPEN=y/# CONFIG_SYS_BOOT_MODE_VERIFIED_OPEN is not set/' .config
#sed -i -e 's/# CONFIG_SYS_BOOT_MODE_VERIFIED_LOCKED is not set/CONFIG_SYS_BOOT_MODE_VERIFIED_LOCKED=y/' .config

linux-${LINUX_VER}/arch/arm/boot/zImage: check_version linux-${LINUX_VER}.tar.xz
	@if [ ! -d "linux-${LINUX_VER}" ]; then \
		unxz --keep linux-${LINUX_VER}.tar.xz; \
		gpg --verify linux-${LINUX_VER}.tar.sign; \
		tar xf linux-${LINUX_VER}.tar && cd linux-${LINUX_VER}; \
	fi
	cp usbarmory_linux-${LINUX_VER_MAJOR}.config linux-${LINUX_VER}/.config
	sed -i -e 's|CONFIG_MODULE_SIG_KEY="certs/signing_key.pem"|CONFIG_MODULE_SIG_KEY="${KEYS_PATH}/usbarmory_chain.pem"|' linux-${LINUX_VER}/.config
	cp ${IMX}-usbarmory.dts linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory.dts
	cd linux-${LINUX_VER} && \
		KBUILD_BUILD_USER=${KBUILD_BUILD_USER} \
		KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST} \
		LOCALVERSION=${LOCALVERSION} \
		ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
		make -j${JOBS} zImage modules ${IMX}-usbarmory.dtb

u-boot-signed.imx: u-boot-tools usbarmory.itb
	cd u-boot-${UBOOT_VER} && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
	${USBARMORY_GIT}/software/secure_boot/usbarmory_csftool \
		--csf_key ${KEYS_PATH}/CSF_1_key.pem \
		--csf_crt ${KEYS_PATH}/CSF_1_crt.pem \
		--img_key ${KEYS_PATH}/IMG_1_key.pem \
		--img_crt ${KEYS_PATH}/IMG_1_crt.pem \
		--table   ${KEYS_PATH}/SRK_1_2_3_4_table.bin \
		--index   1 \
		--image   u-boot-${UBOOT_VER}/u-boot-dtb.imx \
		--output  csf.bin
	cat u-boot-${UBOOT_VER}/u-boot-dtb.imx csf.bin > u-boot-signed.imx

usbarmory.itb: u-boot-tools linux-${LINUX_VER}/arch/arm/boot/zImage
	cd u-boot-${UBOOT_VER} && tools/mkimage -D "-I dts -O dtb -p 2000 -i ../linux-${LINUX_VER}" -f ${USBARMORY_GIT}/software/secure_boot/mark-two/usbarmory.its ../usbarmory.itb
	cd u-boot-${UBOOT_VER} && tools/mkimage -D "-I dts -O dtb -p 2000" -F -k ${KEYS_PATH} -K arch/arm/dts/imx6ull-usbarmory.dtb -r ../usbarmory.itb

linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf.deb: check_version usbarmory.itb mxs-dcp caam-keyblob
	mkdir -p linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN
	mkdir -p linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/boot
	mkdir -p linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/lib/modules
	cat control_template_linux | \
		sed -e 's/XXXX/${LINUX_VER_MAJOR}/'          | \
		sed -e 's/YYYY/${LINUX_VER}${LOCALVERSION}/' | \
		sed -e 's/USB armory/USB armory mark-two/' \
		> linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN/control
	sed -i -e 's/${LINUX_VER_MAJOR}-usbarmory/${LINUX_VER_MAJOR}-usbarmory-mark-two/' linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN/control
	cp -r usbarmory.itb linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/boot/usbarmory-${LINUX_VER}${LOCALVERSION}.itb
	cp -r linux-${LINUX_VER}/.config linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/boot/config-${LINUX_VER}${LOCALVERSION}-usbarmory
	cp -r linux-${LINUX_VER}/System.map linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/boot/System.map-${LINUX_VER}${LOCALVERSION}-usbarmory
	cd linux-${LINUX_VER} && make INSTALL_MOD_PATH=../linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm modules_install
	cp -r linux-${LINUX_VER}/arch/arm/boot/dts/${IMX}-usbarmory.dtb linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/boot/${IMX}-usbarmory-default-${LINUX_VER}${LOCALVERSION}.dtb
	@if test "${IMX}" = "imx6ulz"; then \
		cd mxs-dcp-master && make INSTALL_MOD_PATH=../linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install; \
	fi
	@if test "${IMX}" = "imx6ul"; then \
		cd caam-keyblob-master && make INSTALL_MOD_PATH=../linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf ARCH=arm KERNEL_SRC=../linux-${LINUX_VER} modules_install; \
	fi
	cd linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/boot ; ln -sf usbarmory-${LINUX_VER}${LOCALVERSION}.itb usbarmory.itb
	cd linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/boot ; ln -sf ${IMX}-usbarmory-default-${LINUX_VER}${LOCALVERSION}.dtb ${IMX}-usbarmory.dtb
	cd linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/boot ; ln -sf ${IMX}-usbarmory.dtb imx6ull-usbarmory.dtb
	rm linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/lib/modules/${LINUX_VER}${LOCALVERSION}/build
	rm linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/lib/modules/${LINUX_VER}${LOCALVERSION}/source
	chmod 755 linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf/DEBIAN
	fakeroot dpkg-deb -b linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf.deb


all: check_version linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf.deb u-boot-signed.imx

clean: check_version
	-rm -fr linux-${LINUX_VER}*
	-rm -fr u-boot-${UBOOT_VER}*
	-rm -fr linux-image-usbarmory-mark-two_${LINUX_VER}${LOCALVERSION}_armhf*
	-rm -fr mxs-dcp-master*
	-rm -fr *.imx
	-rm -fr *.itb
