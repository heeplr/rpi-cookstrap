
# create vanilla raspbian image

Example to use rpi-cookstrap to bootstrap a minimal image

run:
```
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard bs=32M status=progress
eject /dev/sdcard
```

* the "raspbian" plugin downloads and decompresses the
  latest raspbian lite image
* the "hostname" plugin sets a random hostname
* the "wifi" plugin configures wireless networking using **RPI_WIFI_***
  settings from *bootstrap.cfg*
