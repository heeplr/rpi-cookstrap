# RPi CookStrap - [![CI](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml/badge.svg)](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml)

A lightweight raspberry pi bakery shell script framework to customize, bootstrap & provision OS disk images with ease.

```
!! A LOT of **sudo** is used. Use at your own risk and do provide fixes ;) !!
```

<div style="font-size:larger;">&#160;</div>


## Why?
Ever been annoyed of customizing your fresh raspberry setup although
you've done the same repetitive tasks already on your past projects?
Not anymore!

Just run *bootstrap.sh* inside your project directory to build a fresh
image for your project. When creating a new project, you now have
building blocks to simply re-use your customization from the past.

You can even create new [plugins](#plugins) for your complex tasks.


<div style="font-size:larger;">&#160;</div>


## Getting started

Try ```./bootstrap.sh -h``` for help.
Your user must be part of the *"disk"* group to use losetup for mounting
the disk image.


### bootstrapping an image

bootstrap.sh will download the latest OS release, mount it via loopback and modifies it. It will change/copy files and add commands to run upon first boot or first login of the pi user (default). The one-time script will delete itself after successful execution leaving you with a clean, pre-configured image.

```
$ cd examples/wifi+ssh
$ ./bootstrap.sh
 ----------------------------------------
  example bootstrap script
 ----------------------------------------
running plugin: download_raspbian
downloading https://downloads.raspberrypi.org/raspbian_lite_latest ...
/tmp/tmp.nyYe5qv7xp                                  100%[=====================================================================================================================>] 433,01M  10,7MB/s    in 44s     
unzipping "/tmp/tmp.nyYe5qv7xp"
Archive:  /tmp/tmp.nyYe5qv7xp
  inflating: 2020-02-13-raspbian-buster-lite.img  
setting up loopback for .bootstrap-work/raspbian-lite.img
Password: 
using "/dev/loop0"
mounting image...
running plugin: hostname
 setting hostname to "example"
 setting /etc/hostname
 processing /etc/hosts
running plugin: wifi
 creating /etc/wpa_supplicant.conf
running plugin: ssh
 copying /etc/ssh/sshd_config ...
cleaning up...


Image creation successful. Copy ".bootstrap-work/raspbian-lite.img" to an SD card.
(e.g. dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard bs=32M status=progress )

$ dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard
$ eject /dev/sdcard
```
with /dev/sdcard being your sdcard, (e.g. /dev/sda)

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


<div style="font-size:larger;">&#160;</div>


## Config
Configuration (i.e. the "receipe" to cook the image) is done by defining
bash key/value pairs in *"bootstrap.cfg"* (must be in same directory as the *"bootstrap.sh"* script)

a minimal working example *"bootstrap.cfg"* file would look like this:
```
RPI_PLUGINS=("download_raspbian")
```
It would just download the default latest raspbian-lite and extract the image.


### built in config variables
Some standard variables are:
* **RPI_PLUGINDIR** - where plugins are located (default: *./bootstrap-plugins*)
* **RPI_DISTDIR** - s. [dist dir](#dist-dir) (default: ./bootstrap_dist)
* **RPI_WORKDIR** - work dir. can be removed at any time to start from scratch (default: *./.bootstrap-work*)
* **RPI_TMPDIR** - temporary dir (default: */tmp*)
* **RPI_ROOT** - mountpoint for root partition (default: *./.bootstrap-work/root*)
* **RPI_BOOT** - mountpoint for boot partition (default: *./.bootstrap-work/boot*)
* **RPI_HOSTNAME** - hostname (default: unnamed)
* **RPI_BOOTSTRAP_PLUGINS** - array of plugin names to run in order (default: () )


<div style="font-size:larger;">&#160;</div>


## Plugins

Plugins are run sequentially. Execution order matters, so e.g.
download plugins always need to run first. They are defined by
the **RPI_BOOTSTRAP_PLUGINS** config variable in bootstrap.cfg

If you want to run the "raspbian_download" plugin to download the image and
configure wireless networking using the "wifi" plugin afterwards for example, you
would set: ```RPI_BOOTSTRAP_PLUGINS=( "raspbian_download" "wifi" )```

Plugins reside in **RPI_PLUGINDIR**.
They all provide a set of functions prefixed by rpi_ and their name (bold ones are non-optional):

* ***_prerun()** - runs before anything is done (before download etc.) Will halt execution when failing.
* *_postrun() - runs after all plugins are done (cleaning up etc.)
* ***_run()** - execute main plugin task. Will also halt execution when failing.
* *_description() - print a general short description of the plugin
* *_help_vars() - call "help_for_vars" function passing an array of "name|helptext|default_value" strings.
* *_help_distfiles() - call "help_for_distfiles" passing an array of "name|helptext" strings

So for example, a plugin named "foo" could define functions
* **rpi_foo_prerun**
* rpi_foo_postrun
* **rpi_foo_run**
* rpi_foo_description
* rpi_foo_help_vars
* rpi_foo_help_distfiles

All plugins can read/write all variables and share one context.


### plugin config variables
All plugins should read variables starting with RPI_ followed by the capitalized plugin name.
So a plugin named "foo" would use RPI_FOO_* and thus could have something like
"RPI_FOO_SOME_VAR=123" in [bootstrap.cfg](#config)


<div style="font-size:larger;">&#160;</div>


## dist dir
The dist dir resembles a root directory tree for plugins to copy files
to the image while preserving the path. Default ''RPI_DISTDIR'' is "./bootstrap_dist)

e.g. the file "./bootstrap_dist/etc/wpa_supplicant/wpa_supplicant.conf"
would be detected by the wifi plugin and end up in "/etc/wpa_supplicant/"
on the image.


<div style="font-size:larger;">&#160;</div>


# Examples
see [examples/](examples/) for further examples
