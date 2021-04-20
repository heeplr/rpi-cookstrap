# RPi CookStrap
[![CI](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml/badge.svg)](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml)

shell script framework to bootstrap & provision raspberry pi OS disk images with ease.


## Getting started

If you want to build a disk image:

```
cd examples/vanilla-ssh
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdX
eject /dev/sdX
```
where /dev/sdX points to your sdcard, (e.g. /dev/sda)

Then boot that image in your raspberrypi.
Trigger one-time self-setup by logging in:
```
ssh pi@host
```
you can replace "host" by an IP address or by a valid domain.

When the script finished, ```reboot``` or ```poweroff```.


If you want to customize your own image:

* copy "bootstrap.sh" to your root directory
* place overlay files/directory into "bootstrap-dist" directory
* place needed plugins into "bootstrap-plugins" directory
* create a bootstrap.cfg
* run ./bootstrap.sh


## Config
Configuration (i.e. the "receipe" to cook the image) is done by defining
bash key/value pairs in *./bootstrap.cfg* (must be in same directory as the *bootstrap.sh* script)

a minimal working example *bootstrap.cfg* file would look like this:
```
RPI_HOSTNAME="myraspberry"
RPI_PLUGINS=("download_raspbian" "hostname")
```

## built in config variables
Some standard variables are:
* **RPI_PLUGINDIR** - where plugins are located (default: *./bootstrap-plugins*)
* **RPI_DISTDIR** - s. [dist dir](#dist-dir) (default: ./bootstrap_dist)
* **RPI_WORKDIR** - temporary work dir. can be removed at any time to start from scratch (default: *./.bootstrap-work*)
* **RPI_ROOT** - mountpoint for root partition (default: *./.bootstrap-work/root*)
* **RPI_BOOT** - mountpoint for boot partition (default: *./.bootstrap-work/boot*)
* **RPI_HOSTNAME** - hostname (default: unnamed)
* **RPI_BOOTSTRAP_PLUGINS** - array of plugin names to run in order (default: () )


## Plugins

Plugins are run sequentially. Execution order matters, so e.g.
download plugins need always to run first. They are defined by
the RPI_BOOTSTRAP_PLUGINS config variable in bootstrap.cfg

Say you want to run the "raspbian_download" to download the image and
configure wireless networking using the "wifi" plugin afterwards. You
would set: ```RPI_BOOTSTRAP_PLUGINS=( "raspbian_download" "wifi" )```

Plugins reside in RPI_PLUGINDIR (default: "./bootstrap-plugins").
They all provide a set of functions prefixed by rpi_ and their name:

* *_prerun() - runs before anything is done (before download etc.) Will halt execution when failing
* *_run() - execute main plugin task. Will also halt exection when failing

So a plugin named "foo" would define functions "rpi_foo_prerun" and "rpi_foo_run".

All plugins can read/write all variables and share one context.


## plugin config variables
All plugins should read variables starting with RPI_ followed by the capitalized plugin name.
So a plugin named "foo" would use RPI_FOO_* and thus could have something like
"RPI_FOO_SOME_VAR=123" in [bootstrap.cfg](#config)

## dist dir
The dist dir resembles a root directory tree for plugins to copy files
to the image while preserving the path. Default ''RPI_DISTDIR'' is "./bootstrap_dist)

e.g. the file "./bootstrap_dist/etc/wpa_supplicant/wpa_supplicant.conf"
would be detected by the wifi plugin and end up in "/etc/wpa_supplicant/"
on the image.

# Examples
see examples/ for further examples
