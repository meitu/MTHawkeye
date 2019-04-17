#!/usr/bin/env bash

set -e

which -s brew
if [[ $? != 0 ]] ; then
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

if ! brew ls --versions clang-format > /dev/null; then
  brew install clang-format
fi

BASE_DIR=$(dirname "$0")

sh $BASE_DIR/Scripts/Hooks/setup-hook.sh

git config commit.template $BASE_DIR/.gitlab/git_commit_templates/Commit_Template.md
