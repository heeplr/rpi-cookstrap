# RPi CookStrap - [![CI](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml/badge.svg)](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml)

A basic shell script framework to bootstrap & provision raspberry pi OS disk images with ease.

```
!! Use with caution. This is "works-for-me" state, mediocre code quality
and a LOT of **sudo** is used. Nothing bad happened, yet but it's just
waiting to happen. Use at your own risk and do provide fixes ;) !!
```

<div align="center" style="font-size:larger;">&#160;</div>


## Why?
Ever been annoyed of customizing your fresh raspberry setup although
you've done the same repetitive tasks already on your past projects?
Not anymore!

Just run *bootstrap.sh* inside your project directory to build a fresh
image for your project. When creating a new project, you now have
building blocks to simply re-use your customization from the past.

You can even create new [plugins](#plugins) for your complex tasks.


<div align="center" style="font-size:larger;">&#160;</div>


## Getting started

Your user must be part of the *"disk"* group to use losetup for mounting
the disk image.


### bootstrapping an image

```
cd examples/wifi+ssh
./bootstrap.sh
dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdX
eject /dev/sdX
```
where /dev/sdX points to your sdcard, (e.g. /dev/sda)

Then boot that image in your raspberrypi.
Trigger one-time self-setup by logging in locally or remotely:
```
ssh pi@host
```
you can replace "host" by an IP address or by a valid domain.



### customizing your own image

* copy *"bootstrap.sh"* to your project directory
* create a *["bootstrap-dist"](#dist-dir)* directory with
all the files you want to copy unchanged to your raspi.
* copy the [plugins](#plugins) you need to *"bootstrap-plugins"* directory
* create a *[bootstrap.cfg](#config)*
* run ```./bootstrap.sh```


<div align="center" style="font-size:larger;">&#160;</div>


## Config
Configuration (i.e. the "receipe" to cook the image) is done by defining
bash key/value pairs in *"bootstrap.cfg"* (must be in same directory as the *"bootstrap.sh"* script)

a minimal working example *"bootstrap.cfg"* file would look like this:
```
RPI_HOSTNAME="myraspberry"
RPI_PLUGINS=("download_raspbian")
```
It would just download the default latest raspbian-lite and extract the image.


### built in config variables
Some standard variables are:
* **RPI_PLUGINDIR** - where plugins are located (default: *./bootstrap-plugins*)
* **RPI_DISTDIR** - s. [dist dir](#dist-dir) (default: ./bootstrap_dist)
* **RPI_WORKDIR** - temporary work dir. can be removed at any time to start from scratch (default: *./.bootstrap-work*)
* **RPI_ROOT** - mountpoint for root partition (default: *./.bootstrap-work/root*)
* **RPI_BOOT** - mountpoint for boot partition (default: *./.bootstrap-work/boot*)
* **RPI_HOSTNAME** - hostname (default: unnamed)
* **RPI_BOOTSTRAP_PLUGINS** - array of plugin names to run in order (default: () )


<div align="center" style="font-size:larger;">&#160;</div>


## Plugins

Plugins are run sequentially. Execution order matters, so e.g.
download plugins always need to run first. They are defined by
the **RPI_BOOTSTRAP_PLUGINS** config variable in bootstrap.cfg

If you want to run the "raspbian_download" plugin to download the image and
configure wireless networking using the "wifi" plugin afterwards for example, you
would set: ```RPI_BOOTSTRAP_PLUGINS=( "raspbian_download" "wifi" )```

Plugins reside in **RPI_PLUGINDIR**.
They all provide a set of functions prefixed by rpi_ and their name:

* *_prerun() - runs before anything is done (before download etc.) Will halt execution when failing.
* *_run() - execute main plugin task. Will also halt execution when failing.

So a plugin named "foo" would define functions "rpi_foo_prerun" and "rpi_foo_run".

All plugins can read/write all variables and share one context.


### plugin config variables
All plugins should read variables starting with RPI_ followed by the capitalized plugin name.
So a plugin named "foo" would use RPI_FOO_* and thus could have something like
"RPI_FOO_SOME_VAR=123" in [bootstrap.cfg](#config)


<div align="center" style="font-size:larger;">&#160;</div>


## dist dir
The dist dir resembles a root directory tree for plugins to copy files
to the image while preserving the path. Default ''RPI_DISTDIR'' is "./bootstrap_dist)

e.g. the file "./bootstrap_dist/etc/wpa_supplicant/wpa_supplicant.conf"
would be detected by the wifi plugin and end up in "/etc/wpa_supplicant/"
on the image.


<div align="center" style="font-size:larger;">&#160;</div>


# Examples
see [examples/](examples/) for further examples
