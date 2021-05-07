
# wifi+upgrade

Setup wifi and perform full upgrade

run:
```
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard bs=32M status=progress
eject /dev/sdcard
```

* the "raspbian" plugin downloads and decompresses the
  latest raspbian lite image
* the "hostname" plugin sets a random hostname
* the "wifi" plugin configures wireless networking using
  *bootstrap-dist/etc/wpa_supplicant/wpa_supplicant.conf*
* the "apt" plugin triggers a full OS upgrade
