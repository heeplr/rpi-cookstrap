
setup() {
    V=1
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-support/load'
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
    RPI_APPEND_APPENDIX=""
    run plugin_prerun append
    assert_failure

    RPI_APPEND_FILE="foo"
    RPI_APPEND_APPENDIX=""
    run plugin_prerun append
    assert_failure

    RPI_APPEND_FILE=""
    RPI_APPEND_APPENDIX="bar"
    run plugin_prerun append
    assert_failure

    RPI_APPEND_FILE="foo"
    RPI_APPEND_APPENDIX="bar"
    run plugin_prerun append
    assert_success
}

@test "plugin_run append: string" {
    local file="${RPI_ROOT}/etc/hostname"
    # check if double string append is prevented
    RPI_APPEND_FILE="${file}"
    RPI_APPEND_APPENDIX="testpi"
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "1" ]
    grep --quiet "testpi" "${file}"

    # check if string append succeeds
    RPI_APPEND_FILE="${file}"
    RPI_APPEND_APPENDIX="# foo"
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "2" ]
    grep -Pz --quiet "(?s)testpi\n# foo" "${file}"

}

@test "plugin_run append: file" {
    local file="${RPI_ROOT}/etc/issue"
    local appendix="${BATS_TMPDIR}/foo.${RANDOM}"
    printf "foo\n" > "${appendix}"
    # check if file append succeeds
    RPI_APPEND_FILE="${file}"
    RPI_APPEND_APPENDIX="${appendix}"
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "2" ]
    grep -Pz --quiet "(?s)Hello!\nfoo" "${file}"

    # check if double file append is prevented
    run plugin_run append
    assert_success
    [ "$(wc -l "${file}" | cut -f1 -d' ')" == "2" ]
    grep -Pz --quiet "(?s)Hello!\nfoo" "${file}"

    # cleanup
    rm "${appendix}"
}
