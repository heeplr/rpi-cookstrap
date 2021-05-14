
# helper to set plugin parameters
function params() {
    RPI_RUN="$1"
    RPI_RUN_ONCE="$2"
    RPI_RUN_MODE="$3"
}


# ---------------------------------------------------------------------
setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="${DIR}/..:${PATH}"
    # config bootstrap
    RPI_PLUGINDIR="${DIR}/../bootstrap-plugins"
    RPI_TESTING="true"
    # init bootstrap
    source bootstrap.sh
    plugin_load run
    # create fake image
    mkdir -p "${RPI_ROOT}/etc"
    mkdir -p "${RPI_ROOT}/home/pi"
    printf "exit 0\n" >> "${RPI_ROOT}/etc/rc.local"
}


@test "plugin_prerun run" {
    params "" "foo" "bar"
    run plugin_prerun run
    assert_failure

    params "foo" "" "bar"
    run plugin_prerun run
    assert_failure

    params "" "" "login"
    run plugin_prerun run
    assert_failure

    params "foo" "" "login"
    run plugin_prerun run
    assert_success

    params "foo" "" "script"
    run plugin_prerun run
    assert_success

    params "foo" "" "boot"
    run plugin_prerun run
    assert_success
}

@test "plugin_run run" {
    params "echo \"foo\"" "" "login"
    plugin_run run
    [ -f "${RPI_ROOT}/home/pi/.bashrc" ]
    grep --quiet 'echo "foo"' "${RPI_ROOT}/home/pi/.bashrc"
    params "" "echo \"foo\"" "login"
    plugin_run run
    [ -f "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_login" ]
    grep --quiet 'echo "foo"' "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_login"
    grep --quiet 'bootstrap_run_on_first_login' "${RPI_ROOT}/home/pi/.bashrc"

    params "echo \"foo\"" "" "boot"
    plugin_run run
    [ -f "${RPI_ROOT}/etc/rc.local" ]
    grep --quiet 'echo "foo"' "${RPI_ROOT}/etc/rc.local"
    params "" "echo \"foo\"" "boot"
    plugin_run run
    [ -f "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_boot" ]
    grep --quiet 'echo "foo"' "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_boot"
    grep --quiet 'bootstrap_run_on_first_boot' "${RPI_ROOT}/etc/rc.local"

    params "echo \"foo\"" "" "script"
    plugin_run run
    [ -f "${RPI_WORKDIR}/rpi_run.sh" ]
    grep --quiet 'echo "foo"' "${RPI_WORKDIR}/rpi_run.sh"
    params "" "echo \"foo\"" "script"
    plugin_run run
    [ -f "${RPI_WORKDIR}/rpi_run_once.sh" ]
    grep --quiet 'echo "foo"' "${RPI_WORKDIR}/rpi_run_once.sh"

}
