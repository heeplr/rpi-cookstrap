
setup() {
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-support/load'
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
    RPI_RUN=""
    RPI_RUN_ONCE="1"
    RPI_RUN_PHASE="bar"
    run plugin_prerun run
    assert_failure

    RPI_RUN="foo"
    RPI_RUN_ONCE=""
    RPI_RUN_PHASE="bar"
    run plugin_prerun run
    assert_failure

    RPI_RUN=""
    RPI_RUN_ONCE=""
    RPI_RUN_PHASE="login"
    run plugin_prerun run
    assert_failure

    RPI_RUN="foo"
    RPI_RUN_ONCE=""
    RPI_RUN_PHASE="login"
    run plugin_prerun run
    assert_success

    RPI_RUN="foo"
    RPI_RUN_ONCE=""
    RPI_RUN_PHASE="bake"
    run plugin_prerun run
    assert_success

    RPI_RUN="foo"
    RPI_RUN_ONCE=""
    RPI_RUN_PHASE="boot"
    run plugin_prerun run
    assert_success
}

@test "plugin_run run" {
    RPI_RUN="echo \"foo\""
    RPI_RUN_ONCE=""
    RPI_RUN_PHASE="login"
    plugin_run run
    [ -f "${RPI_ROOT}/home/pi/.bashrc" ]
    grep --quiet 'echo "foo"' "${RPI_ROOT}/home/pi/.bashrc"

    RPI_RUN="echo \"foo\""
    RPI_RUN_ONCE="1"
    RPI_RUN_PHASE="login"
    plugin_run run
    [ -f "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_login" ]
    grep --quiet 'echo "foo"' "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_login"
    grep --quiet 'bootstrap_run_on_first_login' "${RPI_ROOT}/home/pi/.bashrc"

    RPI_RUN="echo \"foo\""
    RPI_RUN_ONCE=""
    RPI_RUN_PHASE="boot"
    plugin_run run
    [ -f "${RPI_ROOT}/etc/rc.local" ]
    grep --quiet 'echo "foo"' "${RPI_ROOT}/etc/rc.local"

    RPI_RUN="echo \"foo\""
    RPI_RUN_ONCE="1"
    RPI_RUN_PHASE="boot"
    plugin_run run
    [ -f "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_boot" ]
    grep --quiet 'echo "foo"' "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_boot"
    grep --quiet 'bootstrap_run_on_first_boot' "${RPI_ROOT}/etc/rc.local"

    RPI_RUN="touch \"${RPI_WORKDIR}/ran_on_bake\""
    RPI_RUN_ONCE=""
    RPI_RUN_PHASE="bake"
    plugin_run run
    [ -f "${RPI_WORKDIR}/ran_on_bake" ]

    RPI_RUN="touch \"${RPI_WORKDIR}/ran_on_bake_once\""
    RPI_RUN_ONCE="1"
    RPI_RUN_PHASE="bake"
    plugin_run run
    [ -f "${RPI_WORKDIR}/ran_on_bake_once" ]

}
