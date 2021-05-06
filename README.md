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

This will create a working image without any personal customizations:

1. Download/Clone a project or choose an example
   ```cd examples/wifi+upgrade```
   (will setup wifi and perform a full raspbian upgrade)

2. run ```./bootstrap.sh``` and wait until bootstrap is done.
   (It will download the latest OS release, mount it via loopback and
   modify it using it's plugins.)

3. copy image to your SD card:
   ```dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdX conv=fsync status=progress```
   (replace /dev/sdX with you sdcard)

4. boot raspberry pi with image

5. login as "pi" like normal and wait until setup has finished
   (a line into */home/pi/.bashrc* has been added. It executes the
   setup script which deletes itself after successful execution)

Now you got a fresh, upgraded image and wifi setup with wrong
credentials, since *examples/wifi+upgrade/bootstrap.cfg* doesn't
contain your wifi's name and password (hopefully).

It's time to do some customizations. Create a *~/.bootstrap.cfg~*:
```
# WIFI
RPI_BOOTSTRAP_PLUGINS+=( "wifi" )
RPI_WIFI_SSID="yourwifiname"
RPI_WIFI_PSK="your-secret-password"

# SSH
RPI_BOOTSTRAP_PLUGINS+=( "ssh" )
RPI_SSH_AUTHORIZE=( "ssh-ed25519 AAAA... you@host" )

# set random password
RPI_BOOTSTRAP_PLUGINS+=( "password" )
RPI_PASSWORD_PW=( "$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c24;echo;)" )
```

*~/.bootstrap.cfg* is included after the project specific
bootstrap.cfg and override settings accordingly. Also, *~/.bootstrap-plugins*
can contain user plugins and will override project plugins.


This example will:
- run the "wifi" plugin and configure access to your network.
- run the "ssh" plugin, enable the ssh server and authorize
  you@host's key in /home/pi/.ssh/authorized_keys
- run the "password" plugin and set a random 24 char password for the "pi" user

Now repeat step 2 and following from above (run ```./bootstrap.sh``` again).


Try running ```./bootstrap.sh -h``` to list commandline arguments and
```./bootstrap.sh -p``` to list plugins.


## creating your own project

To use bootstrap.sh for building your own projects:

* copy *"bootstrap.sh"* to your project directory
* create a *["bootstrap-dist"](#dist-dir)* directory with
all the files you want to copy/append to your raspi.
* copy the [plugins](#plugins) you need to the *"bootstrap-plugins"*
  directory
* create a *[bootstrap.cfg](#config)*


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

Run ```./bootstrap.sh -p``` for a list of plugins.

Plugins reside in **RPI_PLUGINDIR** (and optionally in **RPI_USER_PLUGINDIR**).
They all provide a set of functions prefixed by rpi_ and their name (bold ones are mandatory):

| function           | description |
|--------------------|-------------------------------------------------------------------------------------------|
|**rpi_*_prerun()**       | runs before anything is done (before download etc.) Will halt execution when failing.
|**rpi_*_run()**          | execute main plugin task. Will also halt execution when failing.
|*rpi_*_postrun()*        | runs after all plugins are done (cleaning up etc.)
|*rpi_*_description()*    | print a general short description of the plugin
|*rpi_*_help_vars()*      | will call "help_for_vars" function passing an array of "name\|helptext\|default_value" strings to describe each variable specific to this plugin.
|*rpi_*_help_distfiles()* | call "help_for_distfiles" passing an array of "name\|helptext" strings to describe each file used by this plugin.

Plugins are run sequentially. Execution order matters, so plugins that provide
a disk image always need to run first.
If you want to run the "raspbian" plugin to download the image and
the "wifi" plugin to configure wireless networking for example, you
would set: ```RPI_BOOTSTRAP_PLUGINS=( "raspbian" "wifi" )```

All plugins can read/write all variables and share one context.
Thus plugins can use other plugins to maximize code reuse.


### plugin config variables
All plugins should read/write variables starting with RPI_ followed by the
capitalized plugin name. So a plugin named "foo" would use RPI_FOO_* and
thus could use a variable like "RPI_FOO_SOME_VAR=123".


### plugin dist files
A plugin can access files in the [dist dir](#dist-dir). Possible
candidates are listed using the ```-p``` argument.


### dist dir
The dist dir resembles a root directory tree for plugins to copy files
to the image while preserving the path. Default ''RPI_DISTDIR'' is "./bootstrap_dist)

e.g. the file "./bootstrap_dist/etc/wpa_supplicant/wpa_supplicant.conf"
would be detected by the wifi plugin and end up in "/etc/wpa_supplicant/"
on the image.


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

