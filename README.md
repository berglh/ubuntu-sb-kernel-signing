## Ubuntu UEFI Secure Boot with Mainline/Custom Kernels
<img src="docs/images/uefi_secure_logo.png" alt="API Connector Module" width="256" align='right'/>

The purpose of this repository is to explain how to sign Ubuntu kernels using a Machine Owner Key. This allows the signed kernels to boot on UEFI Secure Boot enabled computers.

It contains scripts to:

- Create and enrol Machine Owner Key (MOK) for signing kernels
- Post-installation scripts that automate signing of kernels with a MOK

### Topics

- [Introduction](#introduction)
  - [Shim](#shim)
  - [Requirements](#requirements)
- [Usage](#usage)
  - [Creating a MOK for kernel signing](#creating-a-mok-for-kernel-signing)
  - [Automated signing of all installed kernels](#automated-signing-of-all-installed-kernels)
  - [Automated signing of kernels installed with Mainline](#automated-signing-of-kernels-installed-with-mainline)
  - [Manually signing a kernel](#manually-signing-a-kernel)
- [References](#references)

## Introduction

Secure Boot (SB) is a verification mechanism for ensuring that code launched by a computer's UEFI firmware is trustworthy.  UEFI starts bootloaders for operating systems installed on storage devices in the computer. In the context of Linux, the bootloader is usually the grub package. Entries registered in grub allow starting up different Linux kernels or operating systems.

Secure Boot ensures that grub and any operating system kernels are trustworthy. It does this by verifying that the binaries have been signed by a trusted source, such as Ubuntu. It protects users by preventing user-space programs from installing malicious bootloaders and binaries. This is because the rouge software has not been signed by a trusted source. Secure Boot prevents the bootloader from starting distrusted executables.

Ubuntu signs kernels that they distribute through the default APT repositories. The CA certificate is stored in the bootloader packages to validate the kernel signatures. However, not all Ubuntu mainline kernels are published in an APT repository. Ubuntu release frequent builds from the upstream [Linux kernel source code](https://www.kernel.org/) tree.

Linux version releases occur frequently, so it's not possible for Ubuntu to test each version for stability and general use. However, the newer kernel versions often contain performance improvements, bug fixes, new features and hardware support. The untested releases for Ubuntu are published on the following website:

- [Ubuntu Mainline](https://kernel.ubuntu.com/~kernel-ppa/mainline/?C=M;O=D)

Liqourix is another kernel builder that introduces a range of build customisations. It is focused on improving performance for tasks such as gaming.

- [Liqourix](https://liquorix.net/)

Therefore, it's beneficial to have the ability for users to sign kernels that they trust, and wish to install, while keeping Secure Boot enabled.


### Shim

shim is a simple software package that is designed to work as a first-stage bootloader on UEFI systems.  grub loads this as the primary UEFI image on Secure Boot enabled Ubuntu installations.

A key part of the shim design is to allow users to control their own systems.  The distribution CA key is built in to the shim binary.  There is also an extra database of keys that can be managed by the user called Machine Owner Key (MOK for short).

Keys can be added and removed in the MOK list by the user.  The `mokutil` utility can be used to help manage the keys from Linux user-space, but changes to the MOK keys may only be confirmed directly from the console at boot time.  This removes the risk of user-space malware potentially enrolling new keys, which would render Secure Boot useless.

### Requirements

The following items are needed for user MOK signed kernel images with UEFI Secure Boot:

- [UEFI installation of Ubuntu/Linux](https://help.ubuntu.com/community/UEFI)
- [MOK certificate](#creating-a-mok-for-kernel-signing) capable of signing Linux kernel images
- The machine owner key enrolled into shim
- The kernel image is signed with the MOK certificate

## Usage

The issue with using the primary documented method of a user generated MOK is that most guides focus on keys that are used for kernel module signing. These modules are added by packages such as the proprietary nvidia graphics drivers. The Extended Key Usage OID code for module signing is: `1.3.6.1.4.1.2312.16.1.2`. This is mentioned in the Ubuntu blog on "How to sign things for secure boot";

> ### [What about kernels and bootloaders?](https://ubuntu.com/blog/how-to-sign-things-for-secure-boot)
> As long as the signing key is enrolled in shim and does not contain the OID from earlier (since that limits the use of the key to kernel module signing), the binary should be loaded just fine by shim.

Use of the default MOK on a Linux kernel image results in a failure of kernel signature validation. A different MOK that does not contain the OID `1.3.6.1.4.1.2312.16.1.2` by the `shim` bootloader started by `grub`.

Here is the X509 extensions for the default Ubuntu generated MOK. The `1.3.6.1.4.1.2312.16.1.2` code signing OID is present. Thus this can't be used for Secure Boot kernel image validation.

```bash
sudo openssl x509 -text -in /var/lib/shim-signed/mok/MOK.pem
```
```yaml
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
...
       X509v3 extensions:
            X509v3 Subject Key Identifier: 
                BB:97:E4:6A:8C:5A:0E:49:9B:4D:30:57:D1:AE:11:72:07:5C:A7:A4
            X509v3 Authority Key Identifier: 
                keyid:BB:97:E4:6A:8C:5A:0E:49:9B:4D:30:57:D1:AE:11:72:07:5C:A7:A4
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Extended Key Usage: 
                Code Signing, 1.3.6.1.4.1.311.10.3.6, 1.3.6.1.4.1.2312.16.1.2
            Netscape Comment: 
                OpenSSL Generated Certificate
..
```

### Creating a MOK for kernel signing

The script [mok-setup.sh](sbin/mok-setup.sh) guides you through the process of generating a MOK to be used for signing kernels. The script does the following:

1. Creates an OpenSSL config file, stored in the `/etc/ssl/` folder by default, for creating a MOK
2. Creates a new MOK in `/var/lib/shim-signed/mok` named `MOK-Kernel.der` by default
3. Enrolls `MOK-Kernel.der` into `shim`, a reboot is required for this to take effect and import the certificate into the blue MokManager prompt. This process is passphrase protected for security.
4. It can be used for generating other types of MOKs with different Code Signing OIDs.

The script will prompt you for the desired settings, including the output certificate name and config file locations. The script will also check for the required deb packages required before continuing.

```bash
# checkout this repo and enter the sbin folder in the terminal
cd sbin
sudo bash mok-setup.sh
```

### Automated signing of all installed kernels

**Important**: This script will sign any installed kernels automatically. This is not ideal for security so tread carefully. Check the [next section](#automated-signing-of-kernels-installed-with-mainline) for a method that will validate and only sign Ubuntu mainline kernels installed using [mainline](https://github.com/bkw777/mainline).

**Update** 2022-04-28: Renamed signing scripts from `00-` prefix to `zz-` prefix to ensure any other scripts before `zz-update-grub` execute accordingly. This is important so that NVIDIA DKMS modules are generated before the signing script has a chance to fail. This will then enable the DKMS modules to load correctly if Secure Boot is disabled.

The script [zz-signing](sbin/zz-signing) as sourced from [@maxried's Gist](https://gist.github.com/maxried/796d1f3101b3a03ca153fa09d3af8a11), allows you to automatically sign kernels using the `/var/lib/shim-signed/mok/MOK-Kernel.der` certificate. Usage from the Gist:

> This script goes into `/etc/kernel/postinst.d`.
```bash
sudo cp sbin/zz-signing /etc/kernel/postinst.d
```
> You have to make it executable by root: <br>
```bash
sudo chown root:root /etc/kernel/postinst.d/zz-signing
sudo chmod u+rx /etc/kernel/postinst.d/zz-signing
```
> It assists you with automatically signing freshly installed kernel images using the machine owner key in a way similar to what `dkms` does. This is mainly useful if you want to use mainline kernels on Ubuntu on Secure Boot enabled systems. This needs `shim-signed` to be set up. 

**Important**: If you defined a location other than `/var/lib/shim-signed/mok/MOK-Kernel.der` for the kernel signing MOK, you will need to edit the script to change the `MOK_CERT_NAME` variable to match the MOK filename without the extension: i.e. `MOK-my-custom-name`

```bash
set -e

KERNEL_IMAGE="$2"
MOK_CERT_NAME="MOK-Kernel" # edit this line for the cert name, not including the extension
MOK_DIRECTORY="/var/lib/shim-signed/mok" # edit this line if you stored your MOK in a different location
```

A reminder, this script works well for signing **all** kernel images being installed.

###  Automated signing of mainline kernels installed with mainline or via dpkg

**Update** 2022-04-28: Renamed signing scripts from `00-` prefix to `zz-` prefix to ensure any other scripts before `zz-update-grub` execute accordingly. This is important so that NVIDIA DKMS modules are generated before the signing script has a chance to fail. This will then enable the DKMS modules to load correctly if Secure Boot is disabled.

The script [zz-mainline-signing](sbin/zz-mainline-signing) is designed to only sign kernels that are installed using the [mainline](https://github.com/bkw777/mainline) Ubuntu utility or via `dpkg` where the kerenl was downloaded and installed from the [Ubuntu Mainline](https://kernel.ubuntu.com/~kernel-ppa/mainline/?C=M;O=D) website. This script performs additional checks that validate the authenticity of the kernel images.

1. Searches for matching deb files downloaded by mainline
2. Downloads the checksum file from the Ubuntu mainline servers
3. Validates the deb file matches the Ubuntu mainline servers using sha256
4. Extracts the kernel image from the mainline deb to a temporary directory
5. Compares the image to be signed by the script against the kernel image extracted from the mainline deb file
6. Signs the kernel using the MOK

This script goes into `/etc/kernel/postinst.d`.
```bash
sudo cp sbin/zz-mainline-signing /etc/kernel/postinst.d
```
You have to make it executable by root: <br>
```bash
sudo chown root:root /etc/kernel/postinst.d/zz-mainline-signing
sudo chmod u+rx /etc/kernel/postinst.d/zz-mainline-signing
```

**Important**: If you defined a location other than `/var/lib/shim-signed/mok/MOK-Kernel.der` for the kernel signing MOK, you will need to edit the script to change the `MOK_CERT_NAME` variable to match the MOK filename without the extension: i.e. `MOK-my-custom-name`

```bash
set -e

KERNEL_IMAGE="$2"
MOK_CERT_NAME="MOK-Kernel" # edit this line for the cert name, not including the extension
MOK_DIRECTORY="/var/lib/shim-signed/mok" # edit this line if you stored your MOK in a different location
```

**Note**: This has only been tested with kernel versions newer than 5.13.12. The process of extracting the the `data.tar.zst` from the `deb` file is a relatively new process. The previous type had a `tar.xz` file. The script can be modified to work using `xz` decompression for use with older kernels using the commented line below:
```bash
echo "Verify image being signed comes from mainline deb package"
ar p $KERNEL_IMG_DEB data.tar.zst | tar -I zstd -xOf - .$KERNEL_IMAGE > $SIGN_TEMP/$(sed 's:.*/::' <<< $KERNEL_IMAGE)
# ar p $KERNEL_IMG_DEB data.tar.xz | tar -JxOf - .$KERNEL_IMAGE > $SIGN_TEMP/$(sed 's:.*/::' <<< $KERNEL_IMAGE)
```

### Manually signing a kernel

If you install a kernel that doesn't get signed appropriately, you may opt to manually sign the kernel using the MOK certificate generated by [mok-setup.sh](sbin/mok-setup.sh).

**Important**: Ensure as much as possible that the kernel you're signing can be trusted. Validate checksums if available by the download website.

```bash
# List the kernel images installed in /boot
$ sudo ls -l /boot/vmlinuz*
lrwxrwxrwx 1 root root       33 Apr 28 12:15 /boot/vmlinuz -> vmlinuz-5.17.0-4.1-liquorix-amd64
-rw------- 1 root root 10242240 Mar 25 01:27 /boot/vmlinuz-5.13.0-39-generic
-rw------- 1 root root 10243552 Apr 15 02:41 /boot/vmlinuz-5.13.0-41-generic
-rw------- 1 root root 10363176 Apr 25 11:39 /boot/vmlinuz-5.15.6-051506-generic
-rw-r--r-- 1 root root  8164544 Apr 21 10:37 /boot/vmlinuz-5.17.0-4.1-liquorix-amd64
-rw-r--r-- 1 root root  8168584 Apr 28 11:11 /boot/vmlinuz-5.17.0-5.1-liquorix-amd64
lrwxrwxrwx 1 root root       33 Apr 28 12:15 /boot/vmlinuz.old -> vmlinuz-5.17.0-5.1-liquorix-amd64

# Verify the image isn't signed already
$ sudo sbverify --list /boot/vmlinuz-5.17.0-4.1-liquorix-amd64
No signature table present

# Sign the image using the MOK certificate generated by sbin/mok-setup.sh
# Note: 
#   1: Swap out the location of the desired kernel image in --output and the last argument
#   2: You may need to adjust the paths to the MOK cert files if you customised these during the mok-setup.sh script
$ sudo sbsign --key "/var/lib/shim-signed/mok/MOK-Kernel.priv" --cert "/var/lib/shim-signed/mok/MOK-Kernel.pem" --output "/boot/vmlinuz-5.17.0-4.1-liquorix-amd64" "/boot/vmlinuz-5.17.0-4.1-liquorix-amd64"
Signing Unsigned original image

# Verify the image is signed correctly
$ sudo sbverify --list /boot/vmlinuz-5.17.0-4.1-liquorix-amd64
image signature issuers:
 - [ Your MOK issuer information ]
image signature certificates:
 - subject: [ Your MOK key information ]
   issuer:  [ Your MOK issuer information ]
```

## References

I used the following resources to compile this repository:

- https://wiki.ubuntu.com/UEFI/SecureBoot/Testing
- https://answers.launchpad.net/ubuntu/+question/697140
- https://gloveboxes.github.io/Ubuntu-for-Azure-Developers/docs/signing-kernel-for-secure-boot.html
- https://ubuntu.com/blog/how-to-sign-things-for-secure-boot
- https://gist.github.com/maxried/796d1f3101b3a03ca153fa09d3af8a11
- https://github.com/bkw777/mainline/issues/52
