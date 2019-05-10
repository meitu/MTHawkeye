# Contributing to MTHawkeye

Welcome to [report Issues](https://github.com/meitu/MTHawkeye/issues) or [pull requests](https://github.com/meitu/MTHawkeye/pulls). It's recommended to read the following Contributing Guide first before contributing.

## Issues

We use Github Issues to track public bugs and feature requests.

### Search Known Issues First

Please search the existing issues to see if any similar issue or feature request has already been filed. You should make sure your issue isn't redundant.

### Reporting New Issues

If you open an issue, the more information the better. Such as detailed description, screenshot or video of your problem, logcat and xlog or code blocks for your crash.

## Pull Requests

We strongly welcome your pull request to make MTHawkeye better.

### Branch Management

We use [Git Flow branching model](http://nvie.com/posts/a-successful-git-branching-model/) in this repository:

* We use the `master` branch for bringing forth production releases
* We use the `develop` branch for "next release" development.
* We prefix `feature` branch names with `feature/`.
* We prefix `release` branch names with `release/`.
* We prefix `hotfix` branch names with `hotfix/`.

Make commits of logical units of work.

* Smaller / simpler commits are usually easier to review.
* Ideally, lint the files to make sure they do not contain syntax errors before committing them. (`pod lib lint`).
* Ideally, write good commit messages.

## Code Style Guide

Run [Develop Setup Shell](./setup.sh) after clone to makesure `clang-format` git commit hook has installed. Each git commit submitted require verified by clang-format at least, see [.clang-format file](./.clang-format) for basic code style.

## License

By contributing to MTHawkeye, you agree that your contributions will be licensed
under its [MIT LICENSE](./LICENSE)
