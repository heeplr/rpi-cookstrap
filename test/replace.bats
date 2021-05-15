
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
    plugin_load replace
    # create fake image
    mkdir -p "${RPI_ROOT}/etc"
    mkdir -p "${RPI_ROOT}/home/pi"
    printf "exit 0\n" >> "${RPI_ROOT}/etc/rc.local"
}


@test "plugin_prerun replace" {
    RPI_REPLACE_PATTERN=""
    RPI_REPLACE_FILE=""
    run plugin_prerun replace
    assert_failure

    RPI_REPLACE_PATTERN="foo"
    RPI_REPLACE_FILE=""
    run plugin_prerun replace
    assert_failure

    RPI_REPLACE_PATTERN=""
    RPI_REPLACE_FILE="bar"
    run plugin_prerun replace
    assert_failure

    RPI_REPLACE_PATTERN="foo"
    RPI_REPLACE_FILE="bar"
    run plugin_prerun replace
    assert_success
}

@test "plugin_run replace" {
    RPI_REPLACE_PATTERN="exit 0/# exit 0"
    RPI_REPLACE_FILE="${RPI_ROOT}/etc/rc.local"
    run plugin_run replace
    assert_success
    grep --quiet '# exit 0' "${RPI_ROOT}/etc/rc.local"
}
