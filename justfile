set shell := ["zsh", "-eu", "-o", "pipefail", "-c"]

default:
    @just --list

generate:
    xcodegen generate

testflight:
    ./scripts/testflight.sh upload

testflight-build:
    ./scripts/testflight.sh build

testflight-dry-run:
    ./scripts/testflight.sh dry-run
