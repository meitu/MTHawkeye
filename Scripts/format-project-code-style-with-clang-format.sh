#!/usr/bin/env bash
set -e

BASE_DIR=$(dirname "$0")

cd $BASE_DIR

ROOT=$(git rev-parse --show-toplevel)

find -E $ROOT -iregex ".*\.(h|m|c|mm|cpp|hpp|cc|hh|cxx)" -not -path '*/Pods/*' | xargs clang-format -style=file -i -sort-includes
