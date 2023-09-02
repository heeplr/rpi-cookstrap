
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

    # fake distdir
    RPI_DISTDIR="${BATS_TMPDIR}/dist.$RANDOM"
    [[ -d "${RPI_DISTDIR}" ]] || mkdir -p "${RPI_DISTDIR}"
    mkdir -p "${RPI_DISTDIR}/home/pi"
    touch "${RPI_DISTDIR}/home/pi/foo"
    touch "${RPI_DISTDIR}/home/pi/bar"
    mkdir -p "${RPI_DISTDIR}/etc"
    printf "foo" > "${RPI_DISTDIR}/etc/issue"

    # fake boot
    RPI_BOOT="${BATS_TMPDIR}/boot.$RANDOM"
    [[ -d "${RPI_BOOT}" ]] || mkdir -p "${RPI_BOOT}"

    # fake root
    RPI_ROOT="${BATS_TMPDIR}/root.$RANDOM"
    [[ -d "${RPI_ROOT}" ]] || mkdir -p "${RPI_ROOT}"
    mkdir -p "${RPI_ROOT}/etc"
    touch "${RPI_ROOT}/etc/rc.local"
    printf "[all]\n#dtoverlay=vc4-fkms-v3d\ndtparam=audio=off\ndisable_auto_turbo=1\n" > "${RPI_BOOT}/config.txt"
    mkdir -p "${RPI_ROOT}/etc"
    printf "testpi\n" > "${RPI_ROOT}/etc/hostname"
    printf "Hello!\n" > "${RPI_ROOT}/etc/issue"

    # load plugin to test
    plugin_load dist
}

teardown() {
    sudo rm -rf "${RPI_DISTDIR}"
    sudo rm -rf "${RPI_ROOT}"
    sudo rm -rf "${RPI_BOOT}"
}


@test "plugin_prerun dist" {
    RPI_DIST_COPY_ON_BAKE=""
    RPI_DIST_COPY_ON_LOGIN=""
    RPI_DIST_COPY_ON_BOOT=""
    run plugin_prerun dist
    assert_failure
}

@test "plugin_run dist: dir" {
    # on bake: check if dir contents are copied
    RPI_DIST_COPY_ON_BAKE="/home/pi"
    RPI_DIST_COPY_ON_BOOT=""
    RPI_DIST_COPY_LOGIN=""
    plugin_run dist
    [ -f "${RPI_ROOT}/home/pi/foo" ]
    [ -f "${RPI_ROOT}/home/pi/bar" ]
    # on boot: check if dir is copied to image and copy command is added
    RPI_DIST_COPY_ON_BOOT="/home/pi"
    RPI_DIST_COPY_ON_BAKE=""
    RPI_DIST_COPY_LOGIN=""
    plugin_run dist
    [ -f "${RPI_ROOT}/${RPI_IMG_DISTDIR}/home/pi/foo" ]
    [ -f "${RPI_ROOT}/${RPI_IMG_DISTDIR}/home/pi/bar" ]
    grep --quiet 'cp -r' "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_boot"
}

@test "plugin_run dist: file" {
    # on bake: check if file is copied
    RPI_DIST_COPY_ON_BAKE="/etc/issue"
    RPI_DIST_COPY_ON_BOOT=""
    RPI_DIST_COPY_LOGIN=""
    plugin_run dist
    [ -f "${RPI_ROOT}/etc/issue" ]
    RPI_DIST_COPY_ON_BAKE=""
    RPI_DIST_COPY_ON_BOOT="/etc/issue"
    RPI_DIST_COPY_LOGIN=""
    plugin_run dist
    [ -f "${RPI_ROOT}/${RPI_IMG_DISTDIR}/etc/issue" ]
    grep --quiet 'sudo cp "/var/lib/bootstrap-dist//etc/issue"' "${RPI_ROOT}/home/pi/.bootstrap_run_on_first_boot"
}
