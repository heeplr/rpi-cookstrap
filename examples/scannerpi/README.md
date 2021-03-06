
# Raspberry Pi saned network Scanner Server

Connect [sane](http://www.sane-project.org/) compatible scanner(s) to your raspberry pi and share/access them over
the network.


### scannerpi setup
* edit **bootstrap.cfg**
  * change hostname (optional)
  * set ssid/password of your wifi (comment out to disable)
  * add public key for ssh access (comment out to disable)

* edit files in **bootstrap-dist/**
  * *etc/sane.d/saned.conf* - add ip's of all clients or netmask of allowed networks
  * *etc/udev/rules.d/55-libsane.rules* - replace vendor id with vendor id of your scanner (find out with ```lsusb```). Copy/paste line when connecting multiple scanners.

* create sdcard image (replace /dev/sdcard with your sdcard device):
```
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard bs=32M status=progress
eject /dev/sdcard
```
* connect USB scanners using an OTG adapter

* boot sdcard image

* login as pi user to trigger setup
  (prepare coffee, this will take a few minutes)

* reboot the pi



### client setup
* setup sane (if not installed already)
  * Debian/Ubuntu/Mint/...
    * ```apt install sane-utils```

* Append hostname/address of your scannerpi to **/etc/sane.d/net.conf**

Done. You can now use any sane compatible scanner application.

