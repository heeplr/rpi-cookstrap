
# fake plugins
function rpi_fail_run() {
    echo "ran"
    return 1
}

function rpi_success_run() {
    echo "ran"
    return 0
}


# ---------------------------------------------------------------------
setup() {
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-support/load'
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="${DIR}/..:${PATH}"
    RPI_PLUGINDIR="${DIR}/../bootstrap-plugins"
    RPI_TESTING="true"
    source "bootstrap.sh"
}


@test "bootstrap.sh -h" {
    run bootstrap.sh -h
    assert_failure 1
    assert_output --partial - << EOF

Usage: ${DIR}/../bootstrap.sh [-h] [-l] [-v]
 -h    print help text
 -p    plugin help
 -l    leave loopback mounted, don't clean up
 -v    verbose mode
EOF
}

@test "bootstrap.sh -p" {
    run bootstrap.sh -p
    # test if every plugin is included in list
    for p in "${RPI_PLUGINDIR}"/* ; do
        local plugin="$(basename "${p}")"
        assert_output --partial "${plugin}"
    done
}

@test "plugin_check_for_func" {
    # check for a function certainly not available
    run plugin_check_for_func null_func
    assert_failure
    # check for a function that is certainly available
    run plugin_check_for_func plugin_load
    assert_success
}

@test "plugin_load" {
    run plugin_load null_plugin
    assert_failure
    run plugin_load append
    assert_success
}

@test "plugin_run" {
    run plugin_run fail
    assert_output --partial "ran"
    assert_failure
    run plugin_run success
    assert_output --partial "ran"
    assert_success
}

@test "comma array parser" {
    RPI_FOO="bla\,bla, foo, bar,baz"
    commarray RPI_FOO
    [ "${RPI_FOO[0]}" == "bla,bla" ]
    [ "${RPI_FOO[1]}" == "foo" ]
    [ "${RPI_FOO[2]}" == "bar" ]
    [ "${RPI_FOO[3]}" == "baz" ]
}
