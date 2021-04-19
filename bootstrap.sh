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
    type "$2">/dev/null 2>&1 || error "plugin \"$1\" needs a \"$2\" function."
}

# setup loopback device to mount image
function loopback_setup() {
    # valid ?
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
    losetup -d "$1"
    sync
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
    if ! sudo "umount" "${RPI_BOOT}" ; then warn "${RPI_BOOT} not mounted" ; fi
    if ! sudo "umount" "${RPI_ROOT}" ; then warn "${RPI_ROOT} not mounted" ; fi
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
    if [ -z "$1" ] || [ -z "$2" ] ; then error "missing argument. append" ; exit 1 ; fi
    # already appended ?
    [ -f "$1" ] && [ -f "$2" ] && [ -n "$(grep --fixed-strings --file="$1" "$2")" ] && return
    # append
    sudo tee -a "$2" < "$1" >/dev/null || error "sudo_append $1 $2"
}

# append string to file
function append_to_file() {
    if [ -z "$1" ] || [ -z "$2" ] ; then error "missing argument. append" ; fi
    # already appended ?
    [ -f "$2" ] && [ -n "$(sudo grep "$1" "$2")" ] && return
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
    sudo cp "${RPI_DISTDIR}/$1" "${RPI_ROOT}/$(dirname "$1")" || error "cp ${RPI_DISTDIR}/$1 to ${RPI_ROOT}/$(dirname "$1")"
    # chmod?
    [ -n "$2" ] && sudo chmod "$2" "${RPI_ROOT}/$1"
}

# copy if existing
function cp_from_dist_if_exist() {
    dist_exist "$1" && cp_from_dist "$@"
    return 0
}

# chown for pi user
function chown_pi() {
    if [ -z "$1" ] ; then warn "missing argument" ; exit 1 ; fi
    sudo chown 1000:1000 "${RPI_ROOT}/$1" || error "chown ${RPI_ROOT}/$1"
}

# run command once upon first login
function run_once() {
    if [ -z "$1" ] ; then warn "missing argument" ; exit 1 ; fi
    once_script="/home/pi/.bootstrap_run_once"
    if ! [ -f "${RPI_ROOT}/${once_script}" ] ; then
        sudo touch "${RPI_ROOT}/${once_script}" || error "sudo touch"
        append_to_file "if [ -f \"${once_script}\" ] ; then echo \"executing first-time setup...\" ; ${once_script} && rm ${once_script} ; fi" "${RPI_ROOT}/home/pi/.bashrc"
        sudo chmod +x "${RPI_ROOT}/${once_script}" || error "sudo chmod +x"
        sudo chown root:root "${RPI_ROOT}/${once_script}"
    fi
    append_to_file "echo 'executing: $1'" "${RPI_ROOT}/${once_script}"
    append_to_file "$1 || exit 1"         "${RPI_ROOT}/${once_script}"
    chown_pi "${once_script}" || error "chown"
    echo "run once cmd installed: \"$1\""
}

#~ # append string to rc.local
function run_on_boot() {
    if [ -z "$1" ] ; then warn "missing argument" ; exit 1 ; fi
    rc_local="${RPI_ROOT}/etc/rc.local"
    append_to_file "$1" "${rc_local}"
    echo "run boot cmd installed: \"$1\""
}

# disable system service permanently
function disable_service() {
    run_once "sudo systemctl disable \"$1\"" || error "disable_service \"$1\""
}

#~ # append string to config.txt
function append_to_config_txt() {
    for l in "$@" ; do
        append_to_file "$l" "${RPI_BOOT}/config.txt" || error "append"
    done
}

# install a package
function install_package() {
    run_once "sudo apt update"
    run_once "sudo apt upgrade"
    for package in "$@" ; do
        run_once "sudo DEBIAN_FRONTEND=noninteractive apt install --yes --quiet ${package}" || error "install_package"
    done
}


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
    [ -f "${RPI_PLUGINDIR}/$p" ] || error "plugin \"${RPI_PLUGINDIR}/$p\" not found."
    . "${RPI_PLUGINDIR}/$p"
    # check for mandatory functions
    check_for_plugin_function "${p}" "rpi_${p}_run" || error "plugin"
    # run prerun checks
    check_for_plugin_function "${p}" "rpi_${p}_prerun" || error "plugin"
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

echo "Image creation successful. Copy \"${RPI_IMG_NAME}\" to an SD card." \
     "(e.g. dd if=${RPI_IMG_NAME} of=/dev/sdcard bs=256M status=progress )"
