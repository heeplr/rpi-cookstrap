#!/bin/bash

# shellcheck
shellcheck --check-sourced --external-sources --enable all --exclude SC2154 ./bootstrap-plugins/* ./bootstrap.sh || exit 1

# bats tests
for t in test/*.bats ; do
    ./test/bats/bin/bats "${t}" "$@" || exit 1
done
