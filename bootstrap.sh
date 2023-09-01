#!/bin/bash

# rpi-cookstrap - bootstrap self provisioning raspi image
# GPLv3
# Author: Daniel Hiepler (d-cookstrap@coderdu.de) - 2021

RPI_WORKDIR="${RPI_WORKDIR:=${PWD}/.bootstrap-work}"
RPI_PLUGINDIR="${RPI_PLUGINDIR:=${PWD}/bootstrap-plugins}"
RPI_DISTDIR="${RPI_DISTDIR:=${PWD}/bootstrap-dist}"
RPI_IMG_DISTDIR="${RPI_IMG_DISTDIR:=/var/tmp/bootstrap-dist}"
RPI_USER_PLUGINDIR="${RPI_USER_PLUGINDIR:=${HOME}/.bootstrap-plugins}"
RPI_USER_DISTDIR="${RPI_USER_DISTDIR:=${HOME}/.bootstrap-dist}"
RPI_USER_CONFIG="${RPI_USER_CONFIG:=${HOME}/.bootstrap.cfg}"
RPI_TMPDIR="${RPI_TMPDIR:=/tmp}"
RPI_ROOT="${RPI_ROOT:=${RPI_WORKDIR}/root}"
RPI_BOOT="${RPI_BOOT:=${RPI_WORKDIR}/boot}"
RPI_HOSTNAME="${RPI_HOSTNAME:=unnamed}"


# ---------------------------------------------------------------------
VERSION="0.1.0"

# font effects
bold="$(tput bold)"
underline="$(tput smul)"
invert="$(tput smso)"
normal="$(tput sgr0)"
red="$(tput setaf 9)"
green="$(tput setaf 2)"
yellow="$(tput setaf 11)"

# parse comma separated array from var and store in same var
function to_array() {
    local varname="$1"
    local defaultvalue="$2"
    local content
    # var is array?
    if [[ "$(declare -p "${varname}" 2>/dev/null)" =~ "declare -a" ]] ; then
        # don't touch var
        return
    fi
    # parse comma separated string
    content="${!varname}"
    # shellcheck disable=SC2162
    IFS=$'\t'$'\n'", " read -a "${varname?}" <<< "${content:-${defaultvalue}}"
}

# print banner
function banner() {
    cat << EOF
 ----------------------------------------
  ${bold}${RPI_HOSTNAME} bootstrap script${normal}
 ----------------------------------------
EOF
}

# print msg in verbose mode
function verbose() {
    [[ -n "${V}" ]] && echo "[VERBOSE]: $*" 2>&2
    return 0
}

# print log internal msg
function _log() {
    echo "[${bold}INFO${normal}]: $*" 2>&2
    return 0
}

# print log msg
function log() {
    echo " :: $*" 2>&2
    return 0
}

# print warning
function warn() {
    echo "[${yellow}WARNING${normal}]: ${bold}$*${normal}" >&2
    return 0
}

# print error msg
function error() {
    echo "[${red}ERROR${normal}]: ${bold}$*${normal}" >&2
    # just exit normally with error code when testing
    [[ "${RPI_TESTING}" == "true" ]] && exit 1
    # make sure to stop even if we run in a subprocess
    kill -s TERM "${TOP_PID}"
    exit 1
}

# print usage info
function help_usage() {
    cat << EOF

Usage: $0 [-h] [-l] [-v]
 -h          print help text
 -p          all plugins help
 -P <name>   help for specific plugin
 -v          verbose mode
 -l          leave loopback mounted, don't clean up
 -i          ignore ~/.bootstrap*
 -V          show version
EOF
}

# print help of a plugin
function help_plugin() {
    local p="${1}"
    # load this plugin
    plugin_load "${p}"
    # general description
    if plugin_check_for_func "rpi_${p}_description" ; then
        description="$("rpi_${p}_description")"
        printf "%-20s - %s\n\n" "${invert}${bold}${p}${normal}" "${underline}${description}${normal}"
    else
        printf "%-20s\n\n" "${invert}${bold}${p}${normal}"
    fi
    # config var description
    if plugin_check_for_func "rpi_${p}_help_params" ; then
        echo " parameters:"
        "rpi_${p}_help_params"
        echo
    fi
    # distfile description
    if plugin_check_for_func "rpi_${p}_help_distfiles" ; then
        echo " distfiles:"
        "rpi_${p}_help_distfiles"
        echo
    fi
    echo
}

# print plugin help msgs
function help_plugins() {
    # print help for all plugins
    printf "%s plugins:%s\n\n" "${bold}$0" "${normal}"
    local f
    # enable nullglob to not expand * if there are no files
    shopt -s nullglob
    for f in "${RPI_PLUGINDIR}"/* "${RPI_USER_PLUGINDIR}"/* ; do
        # plugin name from path
        local p
        p="$(basename "${f}")"
        help_plugin "${p}"
    done
    # disable nullglob
    shopt -u nullglob
}

# print help for plugin specific parameters
function help_param() {
    local name="$1"
    local description="$2"
    local default="${!name}"
    printf "${bold}%40s${normal} - %s (default: \"%s\")\n" "${name}" "${description}" "${default}"
}

# print help for plugin specific distfiles
function help_distfile() {
    local file="$1"
    printf "%40s\n" "${file}"
}

# parse commandline arguments
function parse_cmdline_args() {
    local arg
    while getopts "hlipP:vV" arg ; do
        case "${arg}" in
            "h")
                # print main help
                help_usage
                exit 1
                ;;

            "l")
                RPI_DONT_CLEANUP="true"
                ;;

            "i")
                RPI_IGNORE_USER_SETTINGS="true"
                ;;

            "p")
                help_plugins
                exit 1
                ;;

            "P")
                help_plugin "${OPTARG}"
                exit 1
                ;;

            "v")
                V="1"
                ;;

            "V")
                echo "rpi-cookstrap v${VERSION}"
                exit 1
                ;;

            ?|*)
                help_usage
                exit 1
                ;;
        esac
    done
}

# check if plugin provides function
function plugin_check_for_func() {
    local funcname="$1"
    type "${funcname}" >/dev/null 2>&1
}

# preflight check for plugin
function plugin_prerun() {
    local plugin="$1"
    plugin_check_for_func "rpi_${plugin}_prerun" || plugin_load "${plugin}"
    verbose "${plugin} prerun"
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
        verbose "loading ${RPI_USER_PLUGINDIR}/${plugin}"
        # (shellcheck cannot source non-constant source)
        # shellcheck disable=SC1090
        . "${RPI_USER_PLUGINDIR}/${plugin}"
    elif [[ -f "${RPI_PLUGINDIR}/${plugin}" ]] ; then
        verbose "loading ${RPI_PLUGINDIR}/${plugin}"
        # (shellcheck cannot source non-constant source)
        # shellcheck disable=SC1090
        . "${RPI_PLUGINDIR}/${plugin}"
    else
        error "plugin \"${plugin}\" load: not found in \"${RPI_PLUGINDIR}\" or \"${RPI_USER_PLUGINDIR}\""
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
    _log "running plugin: ${green}${plugin}${normal}"
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
    verbose "${plugin} postrun"
    "rpi_${plugin}_postrun" || error "postrun \"${plugin}\""
}

# run rpi_*_postrun() of all plugins
function plugin_postrun_all() {
    local p
    for p in "${RPI_BOOTSTRAP_PLUGINS[@]}" ; do
        plugin_postrun "${p}" || error "postrun ${p}"
    done
}

# return all RPI_* variables
function allvars() {
    { set -o posix ; set ; } | grep "RPI_"
}

# ---------------------------------------------------------------------
# ---------------------------------------------------------------------

# are we included ?
if [[ "${RPI_TESTING}" == "true" ]] ; then
    return
else
    # install trap so we can emergency exit everywhere
    trap "exit 1" TERM
    export TOP_PID=$$
fi

# parse cmdline options
parse_cmdline_args "$@"

# parse comma separated array from env var
to_array RPI_BOOTSTRAP_PLUGINS

# load project config
project_config="$(dirname "$0")/bootstrap.cfg"
if [[ -f "${project_config}" ]] ; then
    # (file doesn't need to exist during shellcheck)
    # shellcheck disable=SC1091
    # shellcheck disable=SC1090
    . "$(dirname "$0")/bootstrap.cfg" || warn "loading \"${project_config}\" failed"
    _log "loaded \"${project_config}\""
fi
# load user config (overrides project config)
if [[ -f "${RPI_USER_CONFIG}" ]] && [[ "${RPI_IGNORE_USER_SETTINGS}" != "true" ]] ; then
    # (shellcheck cannot source non-constant source)
    # shellcheck disable=SC1090
    . "${RPI_USER_CONFIG}" 2>/dev/null || warn "loading \"${RPI_USER_CONFIG}\" failed"
    _log "loaded \"${RPI_USER_CONFIG}\""
fi

# remove duplicate entries from RPI_BOOTSTRAP_PLUGINS
# shellcheck disable=SC2312
IFS=" " read -r -a RPI_BOOTSTRAP_PLUGINS <<< "$(tr ' ' '\n' <<< "${RPI_BOOTSTRAP_PLUGINS[@]}" | uniq | tr '\n' ' ')"

# say hello
banner

# check if there are plugins
[[ -n "${RPI_BOOTSTRAP_PLUGINS[*]}" ]] || error "no plugins configured. set RPI_BOOTSTRAP_PLUGINS"

# load plugins
plugin_load_all

# print list of variables
vars="$(allvars)"
verbose "${vars}"


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
    "(e.g. dd if=${RPI_LOOPBACK_IMAGE} of=/dev/sdcard bs=64M status=progress )"
