
# Raspberry Pi saned network Scanner Server

Connect [sane](http://www.sane-project.org/) compatible scanner(s) to your raspberry pi and share/access them over
the network.


### Documentation

#### scannerpi setup
* configure settings in **bootstrap.cfg** and **bootstrap-dist/** files.
* create sdcard image (replace /dev/sdcard with your sdcard device):
```
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard bs=32M status=progress
eject /dev/sdcard
```
* Connect USB-Scanners using an OTG-Adapter
* boot sdcard image
* login as pi user to trigger the first time setup
  (prepare coffee, this will take a few minutes)
* reboot the pi


#### client setup

* setup sane (if not installed already)
  * Debian/Ubuntu/Mint/...
    * ```apt install sane-utils```

* Append hostname/address of your scannerpi to **/etc/sane.d/net.conf**

* use any sane compatible scanner application


Done.
