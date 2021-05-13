#!/bin/bash

for t in test/*.bats ; do
    ./test/bats/bin/bats "${t}" "$@" || exit 1
done
