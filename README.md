## RPi CookStrap - [![CI](https://github.com/heeplr/rpi-cookstrap/actions/workflows/main.yml/badge.svg)](https://github.com/heeplr/rpi-cookstrap/actions/workflows/blank.yml)

A lightweight raspberry pi bakery shell script framework to customize, bootstrap & provision OS disk images with ease.

<div style="font-size:larger;">&#160;</div>

<p align="center">
  <a href="https://asciinema.org/a/LMhf6fXg7pGo9J3B51Mgn2GE4?speed=2" target="_blank">
    <img src="https://asciinema.org/a/LMhf6fXg7pGo9J3B51Mgn2GE4.svg" />
  </a>
</p>

<div style="font-size:larger;">&#160;</div>


# Why?
If you work a lot with raspberry pi's, you find yourself repeatedly
downloading OS images, customize settings like changing config.txt,
set the password, install packages etc.

With rpi-cookstrap you can set up everything beforehand and build the
final image by just running *bootstrap.sh*. When booting or
logging into (default) that image, it will setup itself
non-interactively (default) or interactively.


```
!! A LOT of **sudo** is used. Be aware that
this can cause damage when handled improperly.
Use at your own risk and do provide fixes ;) !!
```


<div style="font-size:larger;">&#160;</div>


# Features

* **lightweight** - written in bash, will run on plain raspberry image,
                configure with any text editor
* **reusable** - [plugins](#plugins) + bootstrap.cfg are building blocks to create
             raspberry pi installations
* **customizable** - create every image with your personal modifications (e.g.
                 your personal wifi credentials)
* **interoperable** - uses shellscripts and standard tools
* **extendable** - plugins can use other [plugins](#plugins) and can be written easily


<div style="font-size:larger;">&#160;</div>


# Getting started

This will create a working raspbian-lite image without any personal customizations.
Wifi will be configured and a full upgrade will be perfomed:

1. Clone and ```cd examples/wifi+upgrade``` (or any other project)

2. run ```./bootstrap.sh``` and wait until bootstrap is done.
   It will load the project's *bootstrap.cfg* and download/modify
   the image accordingly.)

3. copy image to your SD card:
   ```dd if=.bootstrap-work/raspbian-lite.img of=/dev/sdX conv=fsync status=progress```
   (replace /dev/sdX with you sdcard)

4. boot raspberry pi with image

5. login as "pi" like normal and wait until setup has finished
   (a line into */home/pi/.bashrc* has been added. It executes the
   setup script which deletes itself after successful execution)

Now you got a fresh, upgraded image. But the wifi is setup with wrong
credentials, since *examples/wifi+upgrade/bootstrap.cfg* doesn't
contain your wifi's name and password (hopefully).

It's time to do some customizations. Create a *~/.bootstrap.cfg* and
modify according to your needs:
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


*~/.bootstrap.cfg* will be included after the project specific
*bootstrap.cfg* and will override settings accordingly.
(Also, *~/.bootstrap-plugins* can contain user plugins and
 *~/.bootstrap-dist* user distfiles. They will also override
 project plugins or distfiles.)


Now run ```./bootstrap.sh``` again (repeat from step 2 from above).


Also try running ```./bootstrap.sh -h``` to list commandline arguments and
```./bootstrap.sh -p``` to list plugins.


<div style="font-size:larger;">&#160;</div>


# Documentation

Further documentation [can be found in the wiki](https://github.com/heeplr/rpi-cookstrap/wiki).


<div style="font-size:larger;">&#160;</div>


# Examples
see [examples/](examples/) for further examples


<div style="font-size:larger;">&#160;</div>


# Troubleshooting

Everything should be straight forward & verbose. You can always ```rm -rf .bootstrap-work``` to clean up and start over.
Feel free to file an [issue](https://github.com/heeplr/rpi-cookstrap/issues/new) or even submit a pull request.


<div style="font-size:larger;">&#160;</div>


# ToDo
* lots of stuff still missing (plugins, plugin features)
* dry-run mode (output all actions without performing them)
* [tests](https://github.com/sstephenson/bats)

