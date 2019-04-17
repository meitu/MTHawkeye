#!/usr/bin/env bash
set -e

ROOT=$(git rev-parse --show-toplevel)
BASE_DIR=$(dirname "$0")

if [ ! -d $ROOT/.git/hooks ]; then 
    mkdir $ROOT/.git/hooks 
fi 

if [ -f $ROOT/.git/hooks/commit-msg ];then
    echo "File .git/hooks/commit-msg already exists! Will not attempt to overwrite."
else
    cp $BASE_DIR/commit-msg $ROOT/.git/hooks/commit-msg
    chmod +x $ROOT/.git/hooks/commit-msg
fi

if [ -f $ROOT/.git/hooks/pre-commit-clang-format ];then
    echo "File .git/hooks/pre-commit-clang-format already exists! Will not attempt to overwrite."
else
    cp $BASE_DIR/pre-commit-clang-format $ROOT/.git/hooks/pre-commit-clang-format
    chmod +x $ROOT/.git/hooks/pre-commit-clang-format
fi

if [ -f $ROOT/.git/hooks/pre-commit ];then
    echo "File .git/hooks/pre-commit already exists! Will not attempt to overwrite."
else
    cp $BASE_DIR/pre-commit $ROOT/.git/hooks/pre-commit
    chmod +x $ROOT/.git/hooks/pre-commit
fi
