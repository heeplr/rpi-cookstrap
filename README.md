
# RPi CookStrap

shell script framework to bootstrap & provision raspberry pi OS disk images with ease.


## Getting started

If you want to prepare a disk image:

```
cd examples/vanilla-ssh
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdX
```
where /dev/sdX points to your sdcard, (e.g. /dev/sda)


If you want to customize your own image:

* copy "bootstrap.sh" to your root directory
* place overlay files/directory into "bootstrap-dist" directory
* place needed plugins into "bootstrap-plugins" directory
* create bootstrap.cfg
* run ./bootstrap.sh


see examples/ for further examples
