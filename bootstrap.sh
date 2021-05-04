#!/bin/bash

# bootstrap self provisioning raspi image
# GPLv3
# Author: Daniel Hiepler (d-cookstrap@coderdu.de) - 2021


RPI_WORKDIR="${RPI_WORKDIR:=.bootstrap-work}"
RPI_PLUGINDIR="${RPI_PLUGINDIR:=bootstrap-plugins}"
RPI_DISTDIR="${RPI_DISTDIR:=bootstrap-dist}"
RPI_USER_PLUGINDIR="${RPI_USER_PLUGINDIR:=${HOME}/.bootstrap-plugins}"
RPI_USER_DISTDIR="${RPI_USER_DISTDIR:=${HOME}/.bootstrap-dist}"
RPI_USER_CONFIG="${RPI_USER_CONFIG:=${HOME}/.bootstrap.cfg}"
RPI_TMPDIR="${RPI_TMPDIR:=/tmp}"
RPI_ROOT="${RPI_ROOT:=.bootstrap-work/root}"
RPI_BOOT="${RPI_BOOT:=.bootstrap-work/boot}"
RPI_HOSTNAME="${RPI_HOSTNAME:=unnamed}"
RPI_BOOTSTRAP_PLUGINS="${RPI_BOOTSTRAP_PLUGINS:=}"
RPI_PROVISION_ON_BOOT="${RPI_PROVISION_ON_BOOT:=false}"

# ---------------------------------------------------------------------
# print banner
bold="$(tput bold)"
underline="$(tput smul)"
invert="$(tput smso)"
normal="$(tput sgr0)"
red="$(tput setaf 1)"
green="$(tput setaf 2)"

function banner() {
    cat << EOF
 ----------------------------------------
  ${bold}${RPI_HOSTNAME} bootstrap script${normal}
 ----------------------------------------
EOF
}

# print log msg
function log() {
    echo "[INFO]: $*" 2>&2
}

# print warning
function warn() {
    echo "[${bold}WARNING${normal}]: ${bold}$*${normal}" >&2
}

# print error msg
function error() {
    echo "[${red}ERROR${normal}]: ${bold}$* failed.${normal}" >&2
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
function help() {
    # print plugin help
    printf "${bold}Plugins:${normal}\n\n"
    local f
    # enable nullglob to not expand * if there are no files
    shopt -s nullglob
    for f in "${RPI_PLUGINDIR}"/* "${RPI_USER_PLUGINDIR}"/* ; do
        # plugin name from path
        local p
        p="$(basename "${f}")"
        # load this plugin
        plugin_load "${p}"
        # general description
        if plugin_check_for_func "rpi_${p}_description" ; then
            printf "${invert}%-15s${normal} - ${underline}%s${normal}\n\n" "${p}" "$("rpi_${p}_description")"
        else
            printf "${invert}%-15s${normal}\n\n" "${p}"
        fi
        # config var description
        if plugin_check_for_func "rpi_${p}_help_vars" ; then
            echo " variables:"
            "rpi_${p}_help_vars"
            echo
        fi
        # distfile description
        if plugin_check_for_func "rpi_${p}_help_distfiles" ; then
            echo " distfiles:"
            "rpi_${p}_help_distfiles"
            echo
        fi
        echo
    done
    # disable nullglob
    shopt -u nullglob
}

# print help for plugin specific variables
function help_for_vars() {
    local vars=("$@")
    local v
    for v in "${vars[@]}" ; do
        IFS="|" read -r name description default <<< "${v}"
        printf "${bold}%40s${normal} - %s (default: \"%s\")\n" "${name}" "${description}" "${default}"
    done
}

# print help for plugin specific distfiles
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
                help
                exit 1
                ;;

            "l")
                RPI_DONT_CLEANUP=true
                ;;

            *)
                usage
                exit 1
                ;;
        esac
    done
}

# check if plugin provides function
function plugin_check_for_func() {
    local funcname="$1"
    type "${funcname}">/dev/null 2>&1
}

# preflight check for plugin
function plugin_prerun() {
    local plugin="$1"
    plugin_check_for_func "rpi_${plugin}_prerun" || plugin_load "${plugin}"
    "rpi_${plugin}_prerun" || error "preflight check for plugin \"${plugin}\""
    return 0
}

# load plugin and make sure it's not loaded twice
function plugin_load() {
    local plugin="$1"
    # already loaded?
    plugin_check_for_func "rpi_${plugin}_run" && return
    # load plugin
    if [[ -f "${RPI_USER_PLUGINDIR}/${plugin}" ]] ; then
        . "${RPI_USER_PLUGINDIR}/${plugin}"
    elif [[ -f "${RPI_PLUGINDIR}/${plugin}" ]] ; then
        . "${RPI_PLUGINDIR}/${plugin}"
    else
        error "plugin ${plugin} load"
    fi
    # check for mandatory functions
    plugin_check_for_func "rpi_${plugin}_run" || ( warn "plugin \"${plugin}\" needs a \"rpi_${plugin}_run\" function." ; return 1 )
    plugin_check_for_func "rpi_${plugin}_prerun" || ( warn "plugin \"${plugin}\" needs a \"rpi_${plugin}_prerun\" function." ; return 1 )
}

# load all plugins
function plugin_load_all() {
    local p
    # load project plugins
    for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
        # load project plugin
        plugin_prerun "${p}" || error "load ${p}"
    done
}

# run plugin
function plugin_run() {
    local plugin="$1"
    plugin_check_for_func "rpi_${plugin}_run" || error "${plugin} not loaded"
    log "running plugin: ${plugin}"
    "rpi_${plugin}_run" || error "plugin \"${plugin}\" run"
}

# run all plugins
function plugin_run_all() {
    local p
    for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
        plugin_run "${p}" || error "run ${p}"
    done
}

# run rpi_*_postrun() if existing
function plugin_postrun() {
    local plugin="$1"
    # only postrun for plugins that are loaded & provide a postrun()
    plugin_check_for_func "rpi_${plugin}_postrun" || return 0
    "rpi_${plugin}_postrun" || error "postrun \"${plugin}\""
}

# run rpi_*_postrun() of all plugins
function plugin_postrun_all() {
    local p
    for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
        plugin_postrun "${p}" || error "postrun ${p}"
    done
}

# ---------------------------------------------------------------------

# check if dist file exists
function dist_exist() {
    local file="$1"
    [[ -e "${RPI_DISTDIR}/${file}" ]] && return 0
    [[ -e "${RPI_USER_DISTDIR}/${file}" ]] && return 0
    return 1
}

# copy from dist directory to root directory
function cp_from_dist() {
    local path="$1"
    local permissions="$2"
    local dst
    [[ -n "${path}" ]] || error "missing parameter. cp_from_dist"
    log " copying ${path} ..."
    # directory?
    dst="${RPI_ROOT}/$(dirname "${path}")"
    if [[ -d "${RPI_DISTDIR}/${path}" ]] ; then
        sudo cp -r "${RPI_DISTDIR}/${path}/"* "${dst}" || error "cp -r ${path}/* to ${dst}"
    elif [[ -d "${RPI_USER_DISTDIR}/${path}" ]] ; then
        sudo cp -r "${RPI_USER_DISTDIR}/${path}/"* "${dst}" || error "cp -r ${path}/* to ${dst}"
    elif [[ -f "${RPI_DISTDIR}/${path}" ]] ; then
        sudo cp "${RPI_DISTDIR}/${path}" "${dst}" || error "cp ${path} to ${dst}"
    elif [[ -f "${RPI_USER_DISTDIR}/${path}" ]] ; then
        sudo cp "${RPI_USER_DISTDIR}/${path}" "${dst}" || error "cp ${path} to ${dst}"
    else
        error "cp ${path} ${dst}"
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
    log " registering ${path} for copying after boot ..."
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
        sudo cp -r "${RPI_USER_DISTDIR}/${path}"/* "${distdir}/$(dirname "${path}")" || sudo cp -r "${RPI_DISTDIR}/${path}"/* "${distdir}/$(dirname "${path}")" || error "cp"
        # register copy command
        run_once "sudo cp -r \"/home/pi/bootstrap-dist/${path}/\"* \"/$(dirname "${path}")" || error "run_once"
    # copy file?
    else
        sudo cp -r "${RPI_USER_DISTDIR}/${path}" "${distdir}/$(dirname "${path}")/" || sudo cp -r "${RPI_DISTDIR}/${path}" "${distdir}/$(dirname "${path}")/" || error "cp"
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
    rpi_append_to_file "${cmd}" "${RPI_ROOT}/home/pi/.bashrc" || error "rpi_append_to_file"
}

# run command once upon first login
function run_on_first_login() {
    [[ -n "$*" ]] || error "missing argument"
    local once_script="/home/pi/.bootstrap_run_on_first_login"
    # prepare script
    if ! [[ -f "${RPI_ROOT}/${once_script}" ]] ; then
        # call script from .bashrc
        run_on_login "if [[ -f \"${once_script}\" ]] ; then echo \"executing first-time setup...\" ;  time /bin/bash -c \"${once_script} && rm ${once_script} && rm -rf /home/pi/bootstrap-dist\" ; echo \"Done. Please reboot now.\" ; fi"
        sudo touch "${RPI_ROOT}/${once_script}" || error "touch"
        sudo chmod +x "${RPI_ROOT}/${once_script}" || error "sudo chmod +x"
        sudo chown root:root "${RPI_ROOT}/${once_script}" || error "chown"
    fi
    # append to script
    rpi_append_to_file "echo -e '--------------------------------------\nexecuting: $*\n--------------------------------------'" "${RPI_ROOT}/${once_script}"
    rpi_append_to_file "$* || exit 1"         "${RPI_ROOT}/${once_script}"
    chown_pi "${once_script}" || error "chown"
    log " run (login) cmd installed: \"$*\""
}

# run on every boot
function run_on_boot() {
    local cmd="$1"
    # remove "exit 0" at the end if it's there, so we
    # can simply append commands
    rpi_remove_pattern_from_file "exit 0" "${RPI_ROOT}/etc/rc.local" || error "remove exit from rc.local"
    rpi_append_to_file "${cmd}" "${RPI_ROOT}/etc/rc.local" || error "append ${cmd} to rc.local"
}

# run command once upon first boot
function run_on_first_boot() {
    [[ -n "$*" ]] || error "missing argument"
    local once_script="/home/pi/.bootstrap_run_on_first_boot"
    # prepare script
    if ! [[ -f "${RPI_ROOT}/${once_script}" ]] ; then
        # call script from /etc/rc.local
        run_on_boot "if [[ -f \"${once_script}\" ]] ; then echo \"executing first-time setup...\" ; time /bin/bash -c \"${once_script} && rm ${once_script} && rm -rf /home/pi/bootstrap-dist\" ; echo \"Done. Please reboot now.\" ; fi"
        sudo touch "${RPI_ROOT}/${once_script}" || error "touch"
        sudo chmod +x "${RPI_ROOT}/${once_script}" || error "sudo chmod +x"
        sudo chown root:root "${RPI_ROOT}/${once_script}" || error "chown"
    fi
    # append to script
    rpi_append_to_file "echo -e '--------------------------------------\nexecuting: $*\n--------------------------------------'" "${RPI_ROOT}/${once_script}"
    rpi_append_to_file "$* || exit 1"         "${RPI_ROOT}/${once_script}"
    chown_pi "${once_script}" || error "chown"
    log " run (boot) cmd installed: \"$*\""
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

# load project config
{ [[ -f "$(dirname "$0")/bootstrap.cfg" ]] && . "$(dirname "$0")/bootstrap.cfg" ; } || warn "loading bootstrap.cfg failed"
# load user config (overrides project config)
[[ -f "${RPI_USER_CONFIG}" ]] && . "${RPI_USER_CONFIG}" 2>/dev/null

# parse cmdline options
parse_cmdline_args "$@"

# say hello
banner

# check if there are plugins
[[ -n "${RPI_BOOTSTRAP_PLUGINS}" ]] || error "no plugins configured. set RPI_BOOTSTRAP_PLUGINS"

# load plugins
plugin_load_all

# create root mountpoint
[[ -d "${RPI_ROOT}" ]] || mkdir -p "${RPI_ROOT}"
# create boot mountpoint
[[ -d "${RPI_BOOT}" ]] || mkdir -p "${RPI_BOOT}"
# create workdir
[[ -d "${RPI_WORKDIR}" ]] || mkdir -p "${RPI_WORKDIR}"

# run plugins
plugin_run_all

# cleanup
if [[ "${RPI_DONT_CLEANUP}" != "true" ]] ; then
    # run postrun
    plugin_postrun_all
else
    warn "NOT CLEANING UP! Don't forget to umount & losetup -d"
fi

printf "\n\n"
printf "%s\n" \
    "Image creation successful. Copy \"${RPI_LOOPBACK_IMAGE}\" to an SD card." \
    "(e.g. dd if=${RPI_LOOPBACK_IMAGE} of=/dev/sdcard bs=4M conv=fsync status=progress )"
