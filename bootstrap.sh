#!/bin/bash

# bootstrap self provisioning raspi image
# GPLv3
# Author: Daniel Hiepler (d-cookstrap@coderdu.de) - 2021


RPI_WORKDIR="${RPI_WORKDIR:=.bootstrap-work}"
RPI_PLUGINDIR="${RPI_PLUGINDIR:=bootstrap-plugins}"
RPI_DISTDIR="${RPI_DISTDIR:=bootstrap-dist}"
RPI_TMPDIR="${RPI_TMPDIR:=/tmp}"
RPI_ROOT="${RPI_ROOT:=.bootstrap-work/root}"
RPI_BOOT="${RPI_BOOT:=.bootstrap-work/boot}"
RPI_HOSTNAME="${RPI_HOSTNAME:=unnamed}"
RPI_BOOTSTRAP_PLUGINS=()
RPI_PROVISION_ON_BOOT="${RPI_PROVISION_ON_BOOT:=false}"

# ---------------------------------------------------------------------
# print banner
function banner() {
    cat << EOF
 ----------------------------------------
  ${RPI_HOSTNAME} bootstrap script
 ----------------------------------------
EOF
}

# print warning
function warn() {
    echo "$*" >&2
}

# print error msg
function error() {
    echo "error: $* failed." >&2
    exit 1
}

# print usage info
function usage() {
    cat << EOF
Usage: $0 [-h] [-l]
 -h    print help text
 -l    leave loopback mounted, don't clean up

EOF
}

# print help msg
function help_for_vars() {
    local vars=("$@")
    local v
    for v in "${vars[@]}" ; do
        IFS="|" read -r name description default <<< "${v}"
        printf "%30s - %s (default: \"%s\")\n" "${name}" "${description}" "${default}"
    done
}

# print help msg
function help_for_distfiles() {
    local files=("$@")
    local f
    for f in "${files[@]}" ; do
        printf "%40s\n" "${f}"
    done
}

# parse commandline arguments
function parse_cmdline_args() {
    local arg
    while getopts "hl" arg ; do
        case "${arg}" in
            "h")
                # print main help
                usage
                # print plugin help
                printf "Plugins:\n\n"
                local f
                for f in "${RPI_PLUGINDIR}"/* ; do
                    # plugin name from path
                    local p
                    p="$(basename "${f}")"
                    # load this plugin
                    load_plugin "${p}"
                    # general description
                    if check_for_plugin_function "rpi_${p}_description" ; then
                        echo -n "\"${p}\" - "
                        "rpi_${p}_description"
                    else
                        echo "\"${p}\""
                    fi
                    # config var description
                    if check_for_plugin_function "rpi_${p}_help_vars" ; then
                        "rpi_${p}_help_vars"
                        echo
                    fi
                    # distfile description
                    if check_for_plugin_function "rpi_${p}_help_distfiles" ; then
                        echo " distfiles:"
                        "rpi_${p}_help_distfiles"
                        echo
                    fi
                done
                exit 1
                ;;

            "l")
                RPI_DONT_CLEANUP=true
                ;;

            *)
                echo "Usage: $0 [-h] [-l]"
                exit 1
                ;;
        esac
    done
}

# check if plugin provides function
function check_for_plugin_function() {
    local plugin="$1"
    type "${plugin}">/dev/null 2>&1
}

# load plugin and make sure it's not loaded twice
function load_plugin() {
    local plugin="$1"
    # already loaded?
    check_for_plugin_function "rpi_${plugin}_run" && return
    # load plugin
    . "${RPI_PLUGINDIR}/$1"
    # check for mandatory functions
    check_for_plugin_function "rpi_${plugin}_run" || ( warn "plugin \"${plugin}\" needs a \"rpi_${plugin}_run\" function." ; return 1 )
    # run prerun checks
    check_for_plugin_function "rpi_${plugin}_prerun" || ( warn "plugin \"${plugin}\" needs a \"rpi_${plugin}_prerun\" function." ; return 1 )
}

# load all plugins
function load_all_plugins() {
    local p
    for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
        # file existing?
        [[ -f "${RPI_PLUGINDIR}/${p}" ]] || error "plugin \"${RPI_PLUGINDIR}/${p}\" not found."
        # load plugin
        load_plugin "${p}" || error "plugin load ${p}"
        # preflight check
        "rpi_${p}_prerun" || error "preflight check for plugin \"${p}\""
    done
}

# run all plugins
function run_all_plugins() {
    local p
    for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
        echo "running plugin: ${p}"
        "rpi_${p}_run" || error "plugin \"${p}\""
    done
}

# run rpi_*_postrun() if existing
function postrun_all_plugins() {
    local p
    for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
        if check_for_plugin_function "rpi_${p}_postrun" ; then
            "rpi_${p}_postrun" || error "postrun \"${p}\""
        fi
    done
}

# download a file from the internet
function download_file() {
    local url="$1"
    local dstfile="$2"
    if [[ -z "${url}" ]] || [[ -z "${dstfile}" ]] ; then error "missing parameters. download_file" ; fi

    # got URL?
    if echo "${url}" | grep --quiet -E '^(https|http|ftp):/.+$'; then
        # download image
        if command -v wget >/dev/null 2>&1 ; then
            wget --show-progress --quiet --output-document "${dstfile}" "${url}" || error "wget"
        elif command -v curl >/dev/null 2>&1 ; then
            curl --output "${dstfile}" "${url}" || error "curl"
        else
            error "no wget or curl found. ${url} fetch"
        fi
    # treat url as path
    else
        cp "${url}" "${dstfile}" || error "cp"
    fi
}

# setup loopback device to mount image
function loopback_setup() {
    local image="$1"
    # argument valid?
    [[ -f "${image}" ]] || error "${image} not found"
    # already attached?
    local device
    device="$(sudo losetup -l | grep "$(basename "${image}")" | cut -d " " -f1)"
    if [[ -z "${device}" ]] ; then
        # attach image
        device="$(sudo losetup --show --find --partscan "${image}")" || error losetup
    fi
    warn "using \"${device}\""
    echo "${device}"
}

# tear down loopback device
function loopback_cleanup() {
    local device="$1"
    sudo losetup -d "${device}" || warn "loopback cleanup failed"
    sync || warn "sync"
}

# mount raspberry image
function mount_image() {
    local device="$1"

    echo "mounting image..."
    # already mounted?
    if mount | grep --quiet "${device}"; then
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

# ---------------------------------------------------------------------
# append file to file
function append_file_to_file() {
    local appendix="$1"
    local appendee="$2"
    if [[ -z "${appendix}" ]] || [[ -z "${appendee}" ]] ; then error "missing argument. append" ; fi
    # already appended ?
    [[ -f "${appendix}" ]] && [[ -f "${appendee}" ]] && grep --quiet --fixed-strings --file="${appendix}" "${appendee}" && return 0
    # append
    sudo tee -a "${appendee}" < "${appendix}" >/dev/null || error "sudo_append ${appendix} ${appendee}"
}

# append string to file
function append_to_file() {
    local string="$1"
    local file="$2"
    if [[ -z "${string}" ]] || [[ -z "${file}" ]] ; then error "missing argument. append" ; fi
    # already appended ?
    [[ -f "${file}" ]] && sudo grep --fixed-strings --quiet "${string}" "${file}" && return 0
    # append
    sudo touch "${file}"
    printf "%s\n" "${string}" | sudo tee -a "${file}" >/dev/null || error "sudo_append ${string} ${file}"
}

# append input from stdin to file
function append_stdin() {
    local file="$1"
    [[ -n "${file}" ]] || error "missing argument. append_stdin"
    IFS=''
    while read -r appendix ; do
        append_to_file "${appendix}" "${file}"
    done
}

# remove string from file (remove line where pattern matches)
function remove_line_from_file() {
    local pattern="$1"
    local file="$2"
    { [[ -n "${pattern}" ]] && [[ -n "${file}" ]]; } || error "missing arguments. remove line"
    sudo sed "/${pattern}/d" -i "${file}" || error "remove_line ${pattern} ${file}"
}

# replace string in file (sed pattern)
function replace_string_in_file() {
    local pattern="$1"
    local file="$2"
    { [[ -n "${pattern}" ]] && [[ -n "${file}" ]]; } || error "missing arguments. replace line"
    sudo sed -E "s/${pattern}/g" -i "${file}" || error "replace_string ${pattern} ${file}"
}

# check if dist file exists
function dist_exist() {
    local file="$1"
    [[ -e "${RPI_DISTDIR}/${file}" ]] || return 1
    return 0
}

# copy from dist directory to root directory
function cp_from_dist() {
    local path="$1"
    local permissions="$2"
    [[ -n "${path}" ]] || error "missing parameter. cp_from_dist"
    echo " copying ${path} ..."
    # directory?
    if [[ -d "${path}" ]] ; then
        sudo cp -r "${RPI_DISTDIR}/${path}/"* "${RPI_ROOT}/$(dirname "${path}")" || error "cp -r ${path}/* to ${RPI_ROOT}/$(dirname "${path}")"
    else
        sudo cp "${RPI_DISTDIR}/${path}" "${RPI_ROOT}/$(dirname "${path}")" || error "cp ${path} to ${RPI_ROOT}/$(dirname "${path}")"
    fi
    # chmod?
    [[ -n "${permissions}" ]] && chmod_pi "${permissions}" "${path}"
}

# copy if srcfile exists
function cp_from_dist_if_exist() {
    local path="$1"
    if dist_exist "${path}" ; then
        cp_from_dist "${path}"
        return 0
    fi
    return 1
}

# copy from dist directory after boot
function cp_from_dist_after_boot() {
    local path="$1"
    local permissions="$2"
    local distdir="${RPI_ROOT}/home/pi/bootstrap-dist"
    [[ -n "${path}" ]] || error "missing parameter. cp_from_dist_after_boot"
    echo " registering ${path} for copying after boot ..."
    # create directory?
    [[ -d "${distdir}" ]] || {
        sudo mkdir "${distdir}" || error "mkdir"
        chmod_pi "0770" "/home/pi/bootstrap-dist" || error "chmod_pi"
        chown_pi "/home/pi/bootstrap-dist" || error "chown_pi"
    }
    # crate path
    sudo mkdir -p "${distdir}/$(dirname "${path}")/"
    # copy directory?
    if [[ -d "${path}" ]] ; then
        # copy to image
        sudo cp -r "${RPI_DISTDIR}/${path}"/* "${distdir}/$(dirname "${path}")" || error "cp"
        # register copy command
        run_once "sudo cp -r \"/home/pi/bootstrap-dist/${path}/\"* \"/$(dirname "${path}")" || error "run_once"
    # copy file?
    else
        sudo cp -r "${RPI_DISTDIR}/${path}" "${distdir}/$(dirname "${path}")/" || error "cp"
        run_once "sudo cp \"/home/pi/bootstrap-dist/${path}\" \"/$(dirname "${path}")/\"" || error "run_once"
    fi
    # chmod?
    [[ -n "${permissions}" ]] && { run_once "sudo chmod -R \"${permissions}\" \"${path}\"" || error "chmod" ; }
    # chown
    run_once "sudo chown -R pi:pi \"${path}\"" || error "chown"

}

# chown for pi user
function chown_pi() {
    local path="$1"
    local recursive="$2"
    [[ -n "${path}" ]] || error "missing argument"
    if [[ "${recursive}" == "-R" ]] ; then
        sudo chown -R 1000:1000 "${RPI_ROOT}/${path}" || error "chown ${RPI_ROOT}/${path}"
    else
        sudo chown 1000:1000 "${RPI_ROOT}/${path}" || error "chown ${RPI_ROOT}/${path}"
    fi
}

# chmod wrapper
function chmod_pi() {
    local permissions="$1"
    local path="$2"
    local recursive="$3"
    if [[ -z "${permissions}" ]] && [[ -z "${path}" ]] ; then error "missing argument" ; fi
    # directory ?
    if [[ "${recursive}" == "-R" ]] ; then
        sudo find "${RPI_ROOT}/${path}" -type f -exec chmod "${permissions}" {} \;
    else
        sudo chmod "${permissions}" "${RPI_ROOT}/${path}"
    fi
}

# run command on login
function run_on_login() {
    local cmd="$1"
    append_to_file "${cmd}" "${RPI_ROOT}/home/pi/.bashrc" || error "append_to_file"
}

# run command once upon first login
function run_on_first_login() {
    [[ -n "$*" ]] || error "missing argument"
    local once_script="/home/pi/.bootstrap_run_on_first_login"
    # prepare script
    if ! [[ -f "${RPI_ROOT}/${once_script}" ]] ; then
        # call script from .bashrc
        run_on_login "if [[ -f \"${once_script}\" ]] ; then echo \"executing first-time setup...\" ; time ${once_script} && rm ${once_script} ; echo \"Done. Please reboot now.\" ; fi"
        sudo touch "${RPI_ROOT}/${once_script}" || error "touch"
        sudo chmod +x "${RPI_ROOT}/${once_script}" || error "sudo chmod +x"
        sudo chown root:root "${RPI_ROOT}/${once_script}" || error "chown"
    fi
    # append to script
    append_to_file "echo -e '--------------------------------------\nexecuting: $*\n--------------------------------------'" "${RPI_ROOT}/${once_script}"
    append_to_file "$* || exit 1"         "${RPI_ROOT}/${once_script}"
    chown_pi "${once_script}" || error "chown"
    echo " run (login) cmd installed: \"$*\""
}

# run on every boot
function run_on_boot() {
    local cmd="$1"
    # remove "exit 0" at the end if it's there, so we
    # can simply append commands
    remove_line_from_file "exit 0" "${RPI_ROOT}/etc/rc.local" || error "remove exit from rc.local"
    append_to_file "${cmd}" "${RPI_ROOT}/etc/rc.local" || error "append ${cmd} to rc.local"
}

# run command once upon first boot
function run_on_first_boot() {
    [[ -n "$*" ]] || error "missing argument"
    local once_script="/home/pi/.bootstrap_run_on_first_boot"
    # prepare script
    if ! [[ -f "${RPI_ROOT}/${once_script}" ]] ; then
        # call script from /etc/rc.local
        run_on_boot "if [[ -f \"${once_script}\" ]] ; then echo \"executing first-time setup...\" ; time ${once_script} && rm ${once_script} ; echo \"Done. Please reboot now.\" ; fi"
        sudo touch "${RPI_ROOT}/${once_script}" || error "touch"
        sudo chmod +x "${RPI_ROOT}/${once_script}" || error "sudo chmod +x"
        sudo chown root:root "${RPI_ROOT}/${once_script}" || error "chown"
    fi
    # append to script
    append_to_file "echo -e '--------------------------------------\nexecuting: $*\n--------------------------------------'" "${RPI_ROOT}/${once_script}"
    append_to_file "$* || exit 1"         "${RPI_ROOT}/${once_script}"
    chown_pi "${once_script}" || error "chown"
    echo " run (boot) cmd installed: \"$*\""
}

# run command once (either on first boot or on first login)
function run_once() {
    [[ -n "$*" ]] || error "missing argument"
    if [[ "${RPI_PROVISION_ON_BOOT}" == "true" ]] ; then
        run_on_first_boot "$*"
    else
        run_on_first_login "$*"
    fi
}

# ---------------------------------------------------------------------
# ---------------------------------------------------------------------

# load config
if [[ -e "$(dirname "$0")/bootstrap.cfg" ]] ; then . "$(dirname "$0")/bootstrap.cfg" ; fi

# parse cmdline options
parse_cmdline_args "$@"

# say hello
banner

# check if there are plugins
if [[ "${#RPI_BOOTSTRAP_PLUGINS[@]}" == "0" ]] ; then
    error "no plugins configured. set RPI_BOOTSTRAP_PLUGINS"
fi
# load plugins
load_all_plugins

# create root mountpoint
if ! [[ -d "${RPI_ROOT}" ]]  ; then mkdir -p "${RPI_ROOT}" ; fi
# create boot mountpoint
if ! [[ -d "${RPI_BOOT}" ]]  ; then mkdir -p "${RPI_BOOT}" ; fi
# create workdir
if ! [[ -d "${RPI_WORKDIR}" ]]  ; then mkdir -p "${RPI_WORKDIR}" ; fi

# run plugins
run_all_plugins

# cleanup
if [[ "${RPI_DONT_CLEANUP}" != "true" ]] ; then
    # run postrun
    postrun_all_plugins
else
    printf "\nNOT CLEANING UP! Don't forget to umount & losetup -d"
fi

printf "\n\n"
printf "%s\n" \
    "Image creation successful. Copy \"${RPI_IMG_NAME}\" to an SD card." \
    "(e.g. dd if=${RPI_IMG_NAME} of=/dev/sdcard bs=4M conv=fsync status=progress )"
