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

# ---------------------------------------------------------------------
# font effects
bold="$(tput bold)"
underline="$(tput smul)"
invert="$(tput smso)"
normal="$(tput sgr0)"
red="$(tput setaf 9)"
green="$(tput setaf 2)"
yellow="$(tput setaf 11)"

# parse comma separated array from var and store in same var
function commarray() {
    local varname="$1"
    local defaultvalue="$2"
    local content
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
    echo "[${red}ERROR${normal}]: ${bold}$* failed.${normal}" >&2
    exit 1
}

# print usage info
function help_usage() {
    cat << EOF

Usage: $0 [-h] [-l] [-v]
 -h    print help text
 -p    plugin help
 -l    leave loopback mounted, don't clean up
 -v    verbose mode

EOF
}

# print plugin help msgs
function help_plugins() {
    # print plugin help
    printf "%s plugins:%s\n\n" "${bold}$0" "${normal}"
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
            printf "%-20s - %s\n\n" "${invert}${bold}${p}${normal}" "${underline}$("rpi_${p}_description")${normal}"
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
    while getopts "hlpv" arg ; do
        case "${arg}" in
            "h")
                # print main help
                help_usage
                exit 1
                ;;

            "l")
                RPI_DONT_CLEANUP="true"
                ;;

            "p")
                # print plugin help
                help_plugins
                exit 1
                ;;

            "v")
                V="1"
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
        . "${RPI_USER_PLUGINDIR}/${plugin}"
    elif [[ -f "${RPI_PLUGINDIR}/${plugin}" ]] ; then
        verbose "loading ${RPI_PLUGINDIR}/${plugin}"
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
[[ "${RPI_TESTING}" == "true" ]] && return

# parse comma separated array from env var
commarray RPI_BOOTSTRAP_PLUGINS

# load project config
if [[ -f "$(dirname "$0")/bootstrap.cfg" ]] ; then
    . "$(dirname "$0")/bootstrap.cfg" || warn "loading bootstrap.cfg failed"
fi
# load user config (overrides project config)
if [[ -f "${RPI_USER_CONFIG}" ]] ; then
    . "${RPI_USER_CONFIG}" 2>/dev/null && _log "loaded \"${RPI_USER_CONFIG}\""
fi

# parse cmdline options
parse_cmdline_args "$@"

# say hello
banner

# check if there are plugins
[[ -n "${RPI_BOOTSTRAP_PLUGINS[*]}" ]] || error "no plugins configured. set RPI_BOOTSTRAP_PLUGINS"

# load plugins
plugin_load_all

# print list of variables
verbose "$(allvars)"


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
