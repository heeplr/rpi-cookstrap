


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
    plugin_load password
    # create fake image
    mkdir -p "${RPI_ROOT}/etc"
    # create pi user
    printf "pi:x:1000:1000:,,,:/home/pi:/bin/bash\n" > "${RPI_ROOT}/etc/passwd"
    printf "pi:$6$ywwhf4SDBUjh$MkOILJpFJ1B6ypt1cI32KaKQ5Oo8OnQ1yPtXIObG7TCkEx3ejBYg.IiEnts7F1ln3ZFIDYWj2XvpFDBf2CCrm1:18762:0:99999:7:::\n" > "${RPI_ROOT}/etc/shadow"
}


@test "plugin_prerun password" {
    # test missing user
    RPI_PASSWORD_USER=""
    RPI_PASSWORD_PW=""
    run plugin_prerun password
    assert_failure
    # test interactive password entry from stdin
    RPI_PASSWORD_USER="pi"
    RPI_PASSWORD_PW=""
    plugin_prerun password <<< "$(printf "foobar\nfoobar\n")"
    [ "${RPI_PASSWORD_PW}" == "foobar" ]
}

@test "plugin_run password" {
    # change password for pi user
    RPI_PASSWORD_USER="pi"
    RPI_PASSWORD_PW="foobar"
    run plugin_run password
    assert_success
    # make sure  the old hash isn't found
    run grep '$6$ywwhf4SDBUjh$MkOILJpFJ1B6ypt1cI32KaK' "${RPI_ROOT}/etc/shadow"
    assert_failure
}
