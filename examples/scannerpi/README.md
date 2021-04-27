
# Raspberry Pi network Scanner Server

Connect scanner(s) to your raspberry pi and share/access them over
the network.


### Documentation

#### scannerpi setup
configure settings in **bootstrap.cfg** and **bootstrap-dist/**


to create the sd-card image run:

```
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard bs=32M status=progress
eject /dev/sdcard
```
with /dev/sdcard being your sdcard, (e.g. /dev/sda)

Connect USB-Scanners using an OTG-Adapter, boot sdcard image and
login as pi user to trigger the first time setup.


#### client setup

* setup sane (if not installed already)
  * Debian/Ubuntu/Mint/...
    * ```apt install sane-utils```

* Append hostname or ip address of your scannerpi to **/etc/sane.d/net.conf**

* use any sane compatible scanner application


Done.
