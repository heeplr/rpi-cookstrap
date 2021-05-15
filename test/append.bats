
# helper to set plugin parameters
function params() {
    RPI_APPEND_FILE="$1"
    RPI_APPEND_STRING="$2"
    RPI_APPEND_APPENDIX="$3"
}


# ---------------------------------------------------------------------
setup() {
    load 'test_helper/bats-assert/load'
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="${DIR}/..:${PATH}"
    # config bootstrap
    RPI_PLUGINDIR="${DIR}/../bootstrap-plugins"
    RPI_TESTING="true"
    # init bootstrap
    source bootstrap.sh
    plugin_load append
    # create fake image
    mkdir -p "${RPI_BOOT}"
    printf "[all]\n#dtoverlay=vc4-fkms-v3d\ndtparam=audio=off\ndisable_auto_turbo=1\n" > "${RPI_BOOT}/config.txt"
    mkdir -p "${RPI_ROOT}/etc"
    printf "testpi\n" > "${RPI_ROOT}/etc/hostname"
    printf "Hello!\n" > "${RPI_ROOT}/etc/issue"
}


@test "plugin_prerun append" {
    params "" "foo" "bar"
    run plugin_prerun append
    assert_failure
    params "foo" "" "bar"
    run plugin_prerun append
    assert_success
    params "foo" "bar" ""
    run plugin_prerun append
    assert_success
    params "foo" "" ""
    run plugin_prerun append
    assert_failure
    params "" "" "baz"
    run plugin_prerun append
    assert_failure
    params "" "bar" ""
    run plugin_prerun append
    assert_failure
    params "foo" "bar" "baz"
    run plugin_prerun append
    assert_success
}

@test "plugin_run append: string" {
    local file="${RPI_ROOT}/etc/hostname"
    # check if double string append is prevented
    params "${file}" "testpi" ""
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "1" ]

    # check if string append succeeds
    params "${file}" "# foo" ""
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "2" ]
    grep --quiet "testpi" "${file}"
    grep --quiet "# foo" "${file}"

}

@test "plugin_run append: file" {
    local file="${RPI_ROOT}/etc/issue"
    local appendix="${BATS_TMPDIR}/foo"
    printf "foo\n" > "${appendix}"
    # check if file append succeeds
    params "${file}" "" "${appendix}"
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "2" ]
    grep --quiet "Hello!" "${file}"
    grep --quiet "foo" "${file}"
    # check if double file append is prevented
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "2" ]
    grep --quiet "Hello!" "${file}"
    grep --quiet "foo" "${file}"
}
