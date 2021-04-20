#!/bin/bash

# bootstrap self provisioning raspi image
# GPLv3
# Author: Daniel Hiepler 2021


RPI_WORKDIR="${RPI_WORKDIR:=.bootstrap-work}"
RPI_PLUGINDIR="${RPI_PLUGINDIR:=bootstrap-plugins}"
RPI_DISTDIR="${RPI_DISTDIR:=bootstrap-dist}"
RPI_ROOT="${RPI_ROOT:=.bootstrap-work/root}"
RPI_BOOT="${RPI_BOOT:=.bootstrap-work/boot}"
RPI_HOSTNAME="${RPI_HOSTNAME:=unnamed}"
RPI_BOOTSTRAP_PLUGINS=()

# ---------------------------------------------------------------------
# print banner
function banner() {
    echo -e \
        " ----------------------------------------\n" \
        " ${RPI_HOSTNAME} bootstrap script\n" \
        "----------------------------------------\n"
}

# print warning
function warn() {
    echo "$@" >&2
}

# print error msg
function error() {
    echo "error: $@ failed." >&2
    exit 1
}

# check if plugin has function
function check_for_plugin_function() {
    type "$2">/dev/null 2>&1 || return 1
}

# load plugin and make sure it's not loaded twice
function load_plugin() {
    # already loaded?
    check_for_plugin_function "$1" "rpi_$1_run" && return
    # load plugin
    . "${RPI_PLUGINDIR}/$1"
    # check for mandatory functions
    check_for_plugin_function "$1" "rpi_$1_run" || ( warn "plugin \"$1\" needs a \"rpi_$1_run\" function." ; return 1 )
    # run prerun checks
    check_for_plugin_function "$1" "rpi_$1_prerun" || ( error "plugin \"$1\" needs a \"rpi_$1_prerun\" function." ; return 1 )
}

# download a file from the internet
function download_file() {
    url="$1"
    dstfile="$2"
    if [ -z "${url}" ] || [ -z "${dstfile}" ] ; then error "missing parameters. download_file" ; fi

    # got URL?
    if [ -n "$(echo "${url}" | grep -E '^(https|http|ftp):/.+$')" ] ; then
        # download image
        if which wget >/dev/null 2>&1 ; then
            wget --show-progress --quiet --output-document "${dstfile}" "${url}" || error "wget"
        elif which curl >/dev/null 2>&1 ; then
            curl --output "${dstfile}" "${url}" || error "curl"
        else
            error "no wget or curl found. $url fetch"
        fi
    # treat url as path
    else
        cp "${url}" "${dstfile}" || error "cp"
    fi
}

# setup loopback device to mount image
function loopback_setup() {
    # argument valid?
    [ -f "$1" ] || error "$1 not found"
    # already attached?
    device="$(sudo losetup -l | grep "$(basename "$1")" | cut -d " " -f1)"
    if [ -z "${device}" ] ; then
        # attach image
        device="$(sudo losetup --show --find --partscan "${1}")"
        [ $? == 0 ] || error losetup
    fi
    warn "using \"${device}\""
    echo "${device}"
}

# tear down loopback device
function loopback_cleanup() {
    losetup -d "$1" || warn "loopback cleanup"
    sync || warn "sync"
}

# mount raspberry image
function mount_image() {
    device="$1"

    echo "mounting image..."
    # already mounted?
    if [ -n "$(mount | grep "$device")" ] ; then
        return 0
    fi
    # wait for sync
    sync
    # mount
    sudo mount "${device}p1" "${RPI_BOOT}" || return 1
    sudo mount "${device}p2" "${RPI_ROOT}" || return 1
    # read os-release
    . "${RPI_ROOT}/etc/os-release"
    return 0
}

# unmount raspberry image
function umount_image() {
    sudo "umount" "${RPI_BOOT}" || warn "${RPI_BOOT} not mounted"
    sudo "umount" "${RPI_ROOT}" || warn "${RPI_ROOT} not mounted"
    unset PRETTY_NAME
    unset NAME
    unset VERSION_ID
    unset VERSION
    unset ID
    unset ID_LIKE
    unset HOME_URL
    unset SUPPORT_URL
    unset BUG_REPORT_URL
}

# check if dist file exists
function dist_exist() {
    [ -e "${RPI_DISTDIR}/$1" ] || return 1
    return 0
}

# append file to file
function append_file_to_file() {
    if [ -z "$1" ] || [ -z "$2" ] ; then error "missing argument. append" ; fi
    # already appended ?
    [ -f "$1" ] && [ -f "$2" ] && [ -n "$(grep --fixed-strings --file="$1" "$2")" ] && return 0
    # append
    sudo tee -a "$2" < "$1" >/dev/null || error "sudo_append $1 $2"
}

# append string to file
function append_to_file() {
    if [ -z "$1" ] || [ -z "$2" ] ; then error "missing argument. append" ; fi
    # already appended ?
    [ -f "$2" ] && [ -n "$(sudo grep "$1" "$2")" ] && return 0
    # append
    sudo touch "$2"
    echo -e "$1" | sudo tee -a "$2" >/dev/null || error "sudo_append $1 $2"
}

# append input from stdin to file
function append_stdin() {
    [ -n "$1" ] || error "missing argument. append"
    while read appendix ; do
        append_to_file "${appendix}" "$1"
    done
}

# remove string from file (remove line where pattern matches)
function remove_line_from_file() {
    [ -n "$1" ] || error "missing argument. remove line"
    for pattern in "$@" ; do
        sudo sed -i "/$1/d" "$2" || error "sudo_remove $1 $2"
    done
}

# copy from dist directory to root directory
function cp_from_dist() {
    [ -n "$1" ] || error "missing parameter. cp_to_dist"
    echo " copying $1 ..."
    sudo cp "${RPI_DISTDIR}/$1" "${RPI_ROOT}/$(dirname "$1")" || error "cp ${RPI_DISTDIR}/$1 to ${RPI_ROOT}/$(dirname "$1")"
    # chmod?
    [ -n "$2" ] && chmod_pi "$2" "$1"
}

# copy if existing
function cp_from_dist_if_exist() {
    if dist_exist "$1" ; then
        cp_from_dist "$1"
        return 0
    fi
    return 1
}

# chown for pi user
function chown_pi() {
    [ -n "$1" ] || error "missing argument"
    if [ "$2" == "-R" ] ; then
        sudo chown -R 1000:1000 "${RPI_ROOT}/$1" || error "chown ${RPI_ROOT}/$1"
    else
        sudo chown 1000:1000 "${RPI_ROOT}/$1" || error "chown ${RPI_ROOT}/$1"
    fi
}

# chmod wrapper
function chmod_pi() {
    if [ -z "$1" ] && [ -z "$2" ] ; then error "missing argument" ; fi
    # directory ?
    if [ "$3" == "-R" ] ; then
        sudo find "${RPI_ROOT}/$2" -type f -exec chmod "$1" {} \;
    else
        sudo chmod "$1" "${RPI_ROOT}/$2"
    fi
}

# run command once upon first login
function run_on_first_login() {
    [ -n "$1" ] || error "missing argument"
    once_script="/home/pi/.bootstrap_run_on_first_login"
    # prepare script
    if ! [ -f "${RPI_ROOT}/${once_script}" ] ; then
        # call script from .bashrc
        append_to_file "if [ -f \"${once_script}\" ] ; then echo \"executing first-time setup...\" ; ${once_script} && rm ${once_script} ; echo \"Done. Please reboot now.\" ; fi" "${RPI_ROOT}/home/pi/.bashrc"
        sudo touch "${RPI_ROOT}/${once_script}" || error "touch"
        sudo chmod +x "${RPI_ROOT}/${once_script}" || error "sudo chmod +x"
        sudo chown root:root "${RPI_ROOT}/${once_script}" || error "chown"
    fi
    # append to script
    append_to_file "echo 'executing: $@'" "${RPI_ROOT}/${once_script}"
    append_to_file "$@ || exit 1"         "${RPI_ROOT}/${once_script}"
    chown_pi "${once_script}" || error "chown"
    echo " run (login) cmd installed: \"$@\""
}

# run command once upon first boot
function run_on_first_boot() {
    [ -n "$1" ] || error "missing argument"
    once_script="/home/pi/.bootstrap_run_on_first_boot"
    # prepare script
    if ! [ -f "${RPI_ROOT}/${once_script}" ] ; then
        # call script from /etc/rc.local
        remove_line_from_file "exit 0" "${RPI_ROOT}/etc/rc.local" || error "remove exit from rc.local"
        append_to_file "if [ -f \"${once_script}\" ] ; then echo \"executing first-time setup...\" ; ${once_script} && rm ${once_script} ; echo \"Done. Please reboot now.\" ; fi" "${RPI_ROOT}/etc/rc.local"
        sudo touch "${RPI_ROOT}/${once_script}" || error "touch"
        sudo chmod +x "${RPI_ROOT}/${once_script}" || error "sudo chmod +x"
        sudo chown root:root "${RPI_ROOT}/${once_script}" || error "chown"
    fi
    # append to script
    append_to_file "echo 'executing: $@'" "${RPI_ROOT}/${once_script}"
    append_to_file "$@ || exit 1"         "${RPI_ROOT}/${once_script}"
    chown_pi "${once_script}" || error "chown"
    echo " run (boot) cmd installed: \"$@\""
}

# ---------------------------------------------------------------------
# ---------------------------------------------------------------------

# load config
if [ -e "$(dirname $0)/bootstrap.cfg" ] ; then . "$(dirname $0)/bootstrap.cfg" ; fi

# say hello
banner

# check if there are plugins
if [ "${#RPI_BOOTSTRAP_PLUGINS[@]}" == "0" ] ; then
    error "no plugins configured. set RPI_BOOTSTRAP_PLUGINS"
fi
# load plugins
for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
    # file existing?
    [ -f "${RPI_PLUGINDIR}/$p" ] || error "plugin \"${RPI_PLUGINDIR}/$p\" not found."
    # load plugin
    load_plugin "$p" || error "plugin load $p"
    # preflight check
    "rpi_${p}_prerun" || error "preflight check for plugin \"${p}\""
done

# create root mountpoint
if ! [ -d "${RPI_ROOT}" ]  ; then mkdir -p "${RPI_ROOT}" ; fi
# create boot mountpoint
if ! [ -d "${RPI_BOOT}" ]  ; then mkdir -p "${RPI_BOOT}" ; fi
# create workdir
if ! [ -d "${RPI_WORKDIR}" ]  ; then mkdir -p "${RPI_WORKDIR}" ; fi

# run plugins
for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
  echo "running plugin: ${p}"
  "rpi_${p}_run" || error "plugin \"$p\""
done

# cleanup
echo "cleaning up..."
umount_image
loopback_cleanup "${dev}"

echo -e "\n\nImage creation successful. Copy \"${RPI_IMG_NAME}\" to an SD card." \
     "(e.g. dd if=${RPI_IMG_NAME} of=/dev/sdcard bs=32M status=progress )"
