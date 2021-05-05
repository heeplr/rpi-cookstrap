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
RPI_RUN_ON_BOOT="${RPI_RUN_ON_BOOT:=false}"

# ---------------------------------------------------------------------
# font effects
bold="$(tput bold)"
underline="$(tput smul)"
invert="$(tput smso)"
normal="$(tput sgr0)"
red="$(tput setaf 1)"
green="$(tput setaf 2)"

# print banner
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
    printf "%sPlugins:%s\n\n" "${bold}" "${normal}"
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
            printf "%-20s - %s\n\n" "${invert}${p}${normal}" "${underline}$("rpi_${p}_description")${normal}"
        else
            printf "%-20s\n\n" "${invert}${p}${normal}"
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
function help_var() {
    local name="$1"
    local description="$2"
    local default="${!name}"
    printf "${bold}%40s${normal} - %s (default: \"%s\")\n" "${name}" "${description}" "${default}"
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
                RPI_DONT_CLEANUP="true"
                ;;

            ?|*)
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
# ---------------------------------------------------------------------

# load project config
{ [[ -f "$(dirname "$0")/bootstrap.cfg" ]] && . "$(dirname "$0")/bootstrap.cfg" ; } || warn "loading bootstrap.cfg failed"
# load user config (overrides project config)
[[ -f "${RPI_USER_CONFIG}" ]] && . "${RPI_USER_CONFIG}" 2>/dev/null

# parse cmdline options
parse_cmdline_args "$*"

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

printf "\n\n%s\n" \
    "Image creation successful. Copy \"${RPI_LOOPBACK_IMAGE}\" to an SD card." \
    "(e.g. dd if=${RPI_LOOPBACK_IMAGE} of=/dev/sdcard bs=4M conv=fsync status=progress )"
