
# raspi-config

Use the [raspi-config](https://www.raspberrypi.org/documentation/configuration/raspi-config.md) in noninteractive mode to cook image.
s. [bootstrap.cfg](bootstrap.cfg) as example.

run:
```
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard bs=32M status=progress
eject /dev/sdcard
```
