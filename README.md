# RPi CookStrap - [![CI](https://github.com/heeplr/rpi-cookstrap/actions/workflows/main.yml/badge.svg)](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml)

A lightweight raspberry pi bakery shell script framework to customize, bootstrap & provision OS disk images with ease.

bootstrap.sh demo:

[![asciicast](https://asciinema.org/a/ELWTfaMCbMnuIv87KPliFC3G3.svg)](https://asciinema.org/a/ELWTfaMCbMnuIv87KPliFC3G3?speed=4&cols=145&rows=30)


self-provisioning on raspberry pi demo:

[![asciicast](https://asciinema.org/a/4bumTwt4d9WTY9MpJE7MNDsen.svg)](https://asciinema.org/a/4bumTwt4d9WTY9MpJE7MNDsen?speed=4&cols=145&rows=30)


<div style="font-size:larger;">&#160;</div>


## Why?
If you work a lot with raspberry pi's, you find yourself repeatedly
downloading OS images, copy them to the sdcard, customizing settings
like wpa_supplicant.conf or enable ssh.
You then have to boot the image and configure everything (installing
packages, edit config files, etc.)

With rpi-cookstrap you can set up everything beforehand and build the
image by just running *bootstrap.sh*. When booting that image, it will
setup itself attended or unattended.

You can also create new [plugins](#plugins) for complex tasks.

```
!! A LOT of **sudo** is used. Be aware that
this can cause damage when handled improperly.
Use at your own risk and do provide fixes ;) !!
```


<div style="font-size:larger;">&#160;</div>


## Getting started

Try ```./bootstrap.sh -h``` for help.


### bootstrapping an image

*examples/wifi+ssh/bootstrap.sh* will download the latest OS release and mount it via loopback. It will change/copy files and add commands to run upon first boot or first login of the pi user. The one-time script will delete itself after successful execution leaving you with a clean, pre-configured image like if you did it manually.

```
$ cd examples/wifi+ssh
$ ./bootstrap.sh
 ----------------------------------------
  example bootstrap script
 ----------------------------------------
running plugin: raspbian
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

$ dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdcard bs=4M conv=fsync status=progress
$ eject /dev/sdcard
```
with /dev/sdcard being your sdcard, (e.g. /dev/sda)

Boot that image in your raspberrypi and trigger self-setup by logging in locally or remotely:
```
ssh pi@example
```
(replace "example" by the IP address or the FQDN of your pi).



### creating your own project

* copy *"bootstrap.sh"* to your project directory
* create a *["bootstrap-dist"](#dist-dir)* directory with
all the files you want to copy unchanged to your raspi.
* copy the [plugins](#plugins) you need to *"bootstrap-plugins"* directory
* create a *[bootstrap.cfg](#config)*
* run ```./bootstrap.sh```


<div style="font-size:larger;">&#160;</div>


## Config
Configuration (i.e. the "receipe" to cook the image) is done by defining
bash key/value pairs in *"bootstrap.cfg"* (must be in same directory as the
*"bootstrap.sh"* script)

a minimal working example *"bootstrap.cfg"* file would look like this:
```
RPI_PLUGINS=("raspbian")
```
It would just download the default latest raspbian-lite and extract the image.


### builtin config variables

| name                     | description                                                        | default value |
|--------------------------|--------------------------------------------------------------------|---------------|
|**RPI_BOOTSTRAP_PLUGINS** | run those plugins in this order                                    | () |
|**RPI_HOSTNAME**          | hostname the image will use                                        | unnamed
|**RPI_PLUGINDIR**         | path to plugins                                                    | *./bootstrap-plugins*|
|**RPI_DISTDIR**           | s. [dist dir](#dist-dir)                                           | *./bootstrap_dist*|
|**RPI_WORKDIR**           | work dir. can be removed at any time to start from scratch         | *./.bootstrap-work*|
|**RPI_TMPDIR**            | temporary dir                                                      | */tmp*|
|**RPI_USER_PLUGINDIR**    | user specific plugins. If a plugin exists here, it will be prefered over the one in RPI_PLUGINDIR | *~/.bootstrap-plugins*|
|**RPI_USER_DISTDIR**      | user specific distdir. If files exist here, they will be prefered over the ones in RPI_DISTDIR | *~/.bootstrap-dist*|
|**RPI_USER_CONFIG**       | user specific config. Additional to the project's *bootstrap.cfg*  | *~/.bootstrap.cfg*|
|**RPI_ROOT**              | mountpoint for root partition                                      | *./.bootstrap-work/root*
|**RPI_BOOT**              | mountpoint for boot partition                                      | *./.bootstrap-work/boot*


<div style="font-size:larger;">&#160;</div>


## Plugins

Plugins reside in **RPI_PLUGINDIR** (and optionally in **RPI_USER_PLUGINDIR**).
They all provide a set of functions prefixed by rpi_ and their name (bold ones are mandatory):

| function           | description |
|--------------------|-------------------------------------------------------------------------------------------|
|**_prerun()**       | runs before anything is done (before download etc.) Will halt execution when failing.
|**_run()**          | execute main plugin task. Will also halt execution when failing.
|*_postrun()*        | runs after all plugins are done (cleaning up etc.)
|*_description()*    | print a general short description of the plugin
|*_help_vars()*      | will call "help_for_vars" function passing an array of "name\|helptext\|default_value" strings to describe each variable specific to this plugin.
|*_help_distfiles()* | call "help_for_distfiles" passing an array of "name\|helptext" strings to describe each file used by this plugin.

Plugins are run sequentially. Execution order matters, so download plugins
always need to run first.
If you want to run the "raspbian_download" plugin to download the image and
the "wifi" plugin to configure wireless networking for example, you
would set: ```RPI_BOOTSTRAP_PLUGINS=( "raspbian_download" "wifi" )```

All plugins can read/write all variables and share one context.
Thus plugins can use other plugins to maximize code reuse.


### plugin config variables
All plugins should read/write variables starting with RPI_ followed by the
capitalized plugin name. So a plugin named "foo" would use RPI_FOO_* and
thus could use a variable like "RPI_FOO_SOME_VAR=123".


<div style="font-size:larger;">&#160;</div>


## dist dir
The dist dir resembles a root directory tree for plugins to copy files
to the image while preserving the path. Default ''RPI_DISTDIR'' is "./bootstrap_dist)

e.g. the file "./bootstrap_dist/etc/wpa_supplicant/wpa_supplicant.conf"
would be detected by the wifi plugin and end up in "/etc/wpa_supplicant/"
on the image.


<div style="font-size:larger;">&#160;</div>


## Advanced usage

If you build a lot of different rpi-cookstrap projects, you can create a user specific
config, that will be applied to all projects you bootstrap.

### A simple example

Say you want to use the [wifi+upgrade](/examples/wifi+upgrade) example but add your own WIFI
credentials and authorize two of your public keys. Then just create a *~/.bootstrap.cfg* containing:
```
# wifi credentials
RPI_WIFI_SSID="yournetwork"
RPI_WIFI_PSK="very-secret-password"
# ssh pubkey
RPI_SSH_AUTHORIZE=( "ssh-ed25519 AAAA... user1@host" "ssh-ed25519 AAAA... user2@host" )
# run ssh plugin in addition to the plugins from the wifi+upgrade example
RPI_BOOTSTRAP_PLUGINS+=( "ssh" )
```

That's it.

These settings will always override any other RPI_WIFI_SSID/PSK in a project's config.
For arrays, you can append values to not override the project settings. E.g.

```
RPI_APT_CMDS+=( "install screen" )
```
will run "apt install screen" whenever a project runs the apt plugin.

To always run a plugin after all project's plugins are executed, do
```
RPI_BOOTSTRAP_PLUGINS+=( "wifi" )
```
(All plugins *should* behave nicely when run multiple times.)


<div style="font-size:larger;">&#160;</div>


# Examples
see [examples/](examples/) for further examples


<div style="font-size:larger;">&#160;</div>


# Troubleshooting

Everything should be straight forward & verbose. You can always ```rm -rf .bootstrap-work``` to clean up and start over.
Feel free to file an [issue](https://github.com/heeplr/rpi-cookstrap/issues) or even submit a pull request.


<div style="font-size:larger;">&#160;</div>


# ToDo
* detailed plugin documentation (wiki)
* dry-run mode (output all actions without performing them)
* [tests](https://github.com/sstephenson/bats)

