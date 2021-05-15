
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
    RPI_APPEND_FILE=""
    RPI_APPEND_STRING="foo"
    RPI_APPEND_APPENDIX="bar"
    run plugin_prerun append
    assert_failure

    RPI_APPEND_FILE="foo"
    RPI_APPEND_STRING=""
    RPI_APPEND_APPENDIX="bar"
    run plugin_prerun append
    assert_success

    RPI_APPEND_FILE="foo"
    RPI_APPEND_STRING="bar"
    RPI_APPEND_APPENDIX=""
    run plugin_prerun append
    assert_success

    RPI_APPEND_FILE="foo"
    RPI_APPEND_STRING=""
    RPI_APPEND_APPENDIX=""
    run plugin_prerun append
    assert_failure

    RPI_APPEND_FILE=""
    RPI_APPEND_STRING=""
    RPI_APPEND_APPENDIX="baz"
    run plugin_prerun append
    assert_failure

    RPI_APPEND_FILE=""
    RPI_APPEND_STRING="bar"
    RPI_APPEND_APPENDIX=""
    run plugin_prerun append
    assert_failure

    RPI_APPEND_FILE="foo"
    RPI_APPEND_STRING="bar"
    RPI_APPEND_APPENDIX="baz"
    run plugin_prerun append
    assert_success
}

@test "plugin_run append: string" {
    local file="${RPI_ROOT}/etc/hostname"
    # check if double string append is prevented
    RPI_APPEND_FILE="${file}"
    RPI_APPEND_STRING="testpi"
    RPI_APPEND_APPENDIX=""
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "1" ]

    # check if string append succeeds
    RPI_APPEND_FILE="${file}"
    RPI_APPEND_STRING="# foo"
    RPI_APPEND_APPENDIX=""
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
    RPI_APPEND_FILE="${file}"
    RPI_APPEND_STRING=""
    RPI_APPEND_APPENDIX="${appendix}"
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
