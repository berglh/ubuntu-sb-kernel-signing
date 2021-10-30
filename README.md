## Ubuntu UEFI Secure Boot with Mainline/Custom Kernels
<img src="docs/images/uefi_secure_logo.png" alt="API Connector Module" width="256" align='right'/>

The purpose of this repository is to explain how to sign Ubuntu kernels using a Machine Owner Key for use with UEFI Secure Boot.

It contains scripts to:

- Create and enroll Machine Owner Key (MOK) for signing kernels
- Post-installation scripts to automatically sign kernels with the MOK

### Topics

- [Introduction](#introduction)
  - [Shim](#shim)
  - [Requirements](#requirements)
- [Usage](#usage)
  - [Creating a MOK for kernel signing](#creating-a-mok-for-kernel-signing)
  - [Automatically signing all installed kernels](#automatically-signing-all-installed-kernels)
  - [Automatically signing kernels installed with Mainline](#automatically-signing-kernels-installed-with-mainline)
- [References](#references)

## Introduction

UEFI Secure Boot (SB) is a verification mechanism for ensuring that code launched by a computer's UEFI firmware is trusted.  It is designed to protect a system against malicious code being loaded and executed early in the boot process, before the operating system has been loaded.  It is desirable to have this enabled to prevent user space programs from installing malicious booloaders, kernels or kernel modules.

Secure Boot does not work with Ubuntu kernels that were not provided in the Ubuntu APT repositories.  This is because Ubuntu only signs generic kernels that they release into the default repositories.  If booting a non-generic Ubuntu kernel, you will receive an error that the Linux image is not trusted or has an invalid signature.

It's common for advanced Linux users to experiment with newer kernel versions such as those available from:

- [Ubuntu Mainline](https://kernel.ubuntu.com/~kernel-ppa/mainline/?C=M;O=D)
- [Liqourix](https://liquorix.net/)

Hardware bug-fixes, hardware support or kernel features unlock functionality that is often desirable for advanced users.  Different CPU schedulers in non-generic kernels may result in better performance for certain workloads, such as gaming.  Therefore, it's beneficial to have the ability for users to sign kernels that they wish to install while keeping Secure Boot enabled.

### Shim

shim is a simple software package that is designed to work as a first-stage bootloader on UEFI systems.  Grub loads this as the primary EFI image on Secure Boot enabled Ubuntu installations.

A key part of the shim design is to allow users to control their own systems.  The distro CA key is built in to the shim binary itself, but there is also an extra database of keys that can be managed by the user, the so-called Machine Owner Key (MOK for short).

Keys can be added and removed in the MOK list by the user, entirely separate from the distro CA key.  The `mokutil` utility can be used to help manage the keys from Linux userland, but changes to the MOK keys may only be confirmed directly from the console at boot time.  This removes the risk of userland malware potentially enrolling new keys and therefore bypassing the entire point of SB.

### Requirements

The following items are needed to use user MOK signed kernel images with UEFI Secure Boot:

- UEFI installation of Ubuntu/Linux
- MOK certificate capable of signing Linux kernel images
- The machine owner key enrolled into shim
- The kernel image is signed with the MOK certificate

## Usage

The issue with using the primary documented method of a user generated MOK is that most guides focus on keys that are used for kernel module signing. The Extended Key Usage OID code for module signing is: `1.3.6.1.4.1.2312.16.1.2`. This is mentioned in the Ubuntu blog on "How to sign things for secure boot"

> ### [What about kernels and bootloaders?](https://ubuntu.com/blog/how-to-sign-things-for-secure-boot)
> As long as the signing key is enrolled in shim and does not contain the OID from earlier (since that limits the use of the key to kernel module signing), the binary should be loaded just fine by shim.

This results in a failure of kernel signature validation by the `shim` bootloader started by `grub`.

### Creating a MOK for kernel signing

The script [mok-setup.sh](sbin/mok-setup.sh) guides you through the process of generating a MOK to be used for signing kernels. The script does the following:

1. Creates an OpenSSL config file for creating a MOK in the `/etc/ssl/` folder by default
2. Creates a new MOK in `/var/lib/shim-signed/mok` named `MOK-Kernel.der` by default
3. Enrolls `MOK-Kernel.der` into `shim`, a reboot is required for this to take effect and import the certificate into the blue MokManager prompt. This process is passphrase protected for security.

The script will prompt you for the desired settings, including the output certificate name and config file location. The script will also check for the required deb packages required before continuing.

```bash
# checkout this repo and enter the sbin folder in the terminal
cd sbin
sudo bash mok-setup.sh
```

### Automatically signing all installed kernels

**Important**: This script will sign all installed kernels automatically, this is not ideal for security so tread carefully. Check the next section a method that will validate and only sign Ubuntu mainline kernels from a trusted source.

The script [00-signing](sbin/00-signing.sh) as sourced from [@maxried's Gist](https://gist.github.com/maxried/796d1f3101b3a03ca153fa09d3af8a11), allows you to automatically sign kernels using the `/var/lib/shim-signed/mok/MOK-Kernel.der` certificate. Usage from the Gist:

> This script goes into `/etc/kernel/postinst.d`.
```bash
sudo cp sbin/00-signing /etc/kernel/postinst.d
```
> You have to make it executable by root: <br>
```bash
sudo chown root:root /etc/kernel/postinst.d/00-signing
sudo chmod u+rx /etc/kernel/postinst.d/00-signing
```
> It assists you with automatically signing freshly installed kernel images using the machine owner key in a way similar to what `dkms` does. This is mainly useful if you want to use mainline kernels on Ubuntu on Secure Boot enabled systems. This needs `shim-signed` to be set up. 

If you defined a location other than `/var/lib/shim-signed/mok/MOK-Kernel.der` for the kernel signing MOK, you will need to edit the script to change the `MOK_CERT_NAME` variable to match the MOK filename without the extension: i.e. `MOK-my-custom-name`

This script works well for signing **all** kernels being installed.

###  Automatically signing kernels installed with mainline

The script [00-mainline-signing](sbin/00-mainline-signing.sh) is designed to only sign kernels that are installed using the [mainline](https://github.com/bkw777/mainline) Ubuntu kernel installation utility. This script performs additional checks that validate the authenticity of the Ubuntu mainline kernels.

1. Searches for matching deb files downloaded by mainline
2. Downloads the checksum file from the Ubuntu mainline servers
3. Validates the deb file matches the Ubuntu mainline servers using sha256
4. Extracts the kernel image from the mainline deb to a temporary directory
5. Compares the image to be signed by the script against the kernel image extracted from the mainline deb file
6. Signs the kernel using the MOK

This script goes into `/etc/kernel/postinst.d`.
```bash
sudo cp sbin/00-mainline-signing /etc/kernel/postinst.d
```
You have to make it executable by root: <br>
```bash
sudo chown root:root /etc/kernel/postinst.d/00-mainline-signing
sudo chmod u+rx /etc/kernel/postinst.d/00-mainline-signing
```
**Important**: If you defined a location other than `/var/lib/shim-signed/mok/MOK-Kernel.der` for the kernel signing MOK, you will need to edit the script to change the `MOK_CERT_NAME` variable to match the MOK filename without the extension: i.e. `MOK-my-custom-name`


## References

I used the following resources to compile this repository:

- https://wiki.ubuntu.com/UEFI/SecureBoot/Testing
- https://answers.launchpad.net/ubuntu/+question/697140
- https://gloveboxes.github.io/Ubuntu-for-Azure-Developers/docs/signing-kernel-for-secure-boot.html
- https://ubuntu.com/blog/how-to-sign-things-for-secure-boot
- https://gist.github.com/maxried/796d1f3101b3a03ca153fa09d3af8a11
- https://github.com/bkw777/mainline/issues/52