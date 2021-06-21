## RPi CookStrap - [![CI](https://github.com/heeplr/rpi-cookstrap/actions/workflows/main.yml/badge.svg)](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml)

A lightweight, plugin based bakery shell script framework to customize, bootstrap & provision raspberry pi OS disk images.


<div style="font-size:larger;">&#160;</div>


# Features

* **lightweight** - written in bash, will run on plain raspberry image,
                no additional installation needed on the pi, configure with any text editor
* **reusable** - [plugins](../../wiki/Doc-Plugins) + [bootstrap.cfg](../../wiki/Doc-Config) are building blocks to create
             raspberry pi installations
* **customizable** - do your personal customizations once (e.g.
                 your personal wifi credentials) and use them with every project 
* **interoperable** - uses shellscripts and standard tools
* **extendable** - plugins can use other [plugins](../../wiki/Doc-Plugins) and can be written easily


<div style="font-size:larger;">&#160;</div>


<p align="center">
  <a href="https://asciinema.org/a/LMhf6fXg7pGo9J3B51Mgn2GE4?speed=2" target="_blank">
    <img src="https://asciinema.org/a/LMhf6fXg7pGo9J3B51Mgn2GE4.svg" />
  </a>
</p>
Complete demo of image download, bootstrap, flash and setup on pi login. 

(2x speed, most of it is output from apt on the pi, use pause if it's too fast)


<div style="font-size:larger;">&#160;</div>


# Why?
If you work a lot with raspberry pi's, you find yourself repeatedly
downloading OS images, customize settings like changing /config.txt,
set the password, setup network, install packages, copy files etc.

With rpi-cookstrap you can create & use building blocks to build your
final image by just running *bootstrap.sh*. When booting or
logging in, the image can setup everything by itself non-interactively
(default) or interactively.


<div style="font-size:larger;">&#160;</div>


# Quickstart

```
RPI_BOOTSTRAP_PLUGINS=raspbian,password RPI_PASSWORD_PW=secret ./bootstrap.sh
```

is a minimal example and will download the latest raspbian lite and set the password of the *pi* user to "secret".


<div style="font-size:larger;">&#160;</div>


# Basic usage by example

The *wifi+upgrade* example will create a working raspbian-lite image without any personal customizations.
Wifi will be configured (with the preset SSID and PSK) and a full upgrade will be perfomed:

The following will:
* ...clone rpi-cookstrap
* ...load the project's *bootstrap.cfg* and download/modify the image accordingly.
* ...write the freshly baked image to your SD card (replace /dev/sdX with you sdcard)

```
$ git clone https://github.com/heeplr/rpi-cookstrap
$ cd rpi-cookstrap/examples/wifi+upgrade
$ ./bootstrap.sh
$ dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdX conv=fsync status=progress
```
* Then boot raspberry pi with image
* login as "pi" like normal and wait until setup has finished
   (a line into */home/pi/.bashrc* has been added. It executes the
   setup script which deletes itself after successful execution)

Now you got a fresh and fully upgraded image. But the wifi is setup with wrong
credentials, since *examples/wifi+upgrade/bootstrap.cfg* doesn't
contain your wifi's name and password (hopefully).


<div style="font-size:larger;">&#160;</div>


# Integration into your project
You can add rpi-cookstrap into your raspberry project simply by using symbolic links.
e.g. with a git submodule:
```
$ cd my-raspberry-project-image
$ git submodule add https://github.com/heeplr/rpi-cookstrap bootstrap
$ ln -s bootstrap/bootstrap.sh bootstrap.sh
$ ln -s bootstrap/bootstrap-plugins bootstrap-plugins
```
Then create bootstrap *bootstrap.cfg* and *bootstrap-dist* in your project directory (s. below).


<div style="font-size:larger;">&#160;</div>


# Permanent customization
You can create a customized config that will always override a project's *bootstrap.cfg*:
Create *~/.bootstrap.cfg* and modify according to your needs, for example (comment out to disable):
```
# setup WIFI
RPI_BOOTSTRAP_PLUGINS+=( "wifi" )
RPI_WIFI_SSID="yourwifiname"
RPI_WIFI_PSK="your-secret-password"

# authorize SSH public key
RPI_BOOTSTRAP_PLUGINS+=( "ssh" )
RPI_SSH_AUTHORIZE=( "ssh-ed25519 AAAA... you@host" )

# set random 24 char PASSWORD for pi user
RPI_BOOTSTRAP_PLUGINS+=( "password" )
RPI_PASSWORD_PW=( "$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c24;echo;)" )
```

Now if you run ```./bootstrap.sh``` for any project, the image is created with
your personal settings.


<div style="font-size:larger;">&#160;</div>


# Documentation

Try running ```./bootstrap.sh -h``` to list commandline arguments and
```./bootstrap.sh -p``` to list [plugins](../../wiki/plugins).

Further documentation [can be found in the wiki](../../wiki/).


<div style="font-size:larger;">&#160;</div>


# Plugins
The wiki has a [list of available plugins](../../wiki/plugins).
There's also more [documentation on the general plugin concept](../../wiki/Doc-Plugins).


<div style="font-size:larger;">&#160;</div>


# More Examples
see [examples/](examples/) for "complete" examples and [plugin's](../../wiki/plugins) documentation for plugin specific examples.


<div style="font-size:larger;">&#160;</div>


# Troubleshooting

Everything should be straight forward & verbose. You can always ```rm -rf .bootstrap-work``` to clean up and start over.
Feel free to file an [issue](https://github.com/heeplr/rpi-cookstrap/issues/new) or even submit a pull request.


<div style="font-size:larger;">&#160;</div>


# ToDo
* lots of stuff still missing (plugins, plugin features)
* better documentation
* more examples
* dry-run mode (output all actions without performing them)
* more [tests](test/)

Contributions welcome!
