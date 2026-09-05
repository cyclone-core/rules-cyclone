"""rules_cyclone 公共入口：用户在 BUILD 中 load 的唯一文件。

    load("@rules_cyclone//cyclone:defs.bzl", "cyclone_test")
"""

load("//cyclone/private:cyclone_test.bzl", _cyclone_test = "cyclone_test")
load("//tools:toolchain.bzl", _cyclone_toolchain = "cyclone_toolchain")

cyclone_test = _cyclone_test
cyclone_toolchain = _cyclone_toolchain
