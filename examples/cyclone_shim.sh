#!/usr/bin/env bash
# 本地开发 shim：把本仓 cyclone 包的 python 入口包装成"cyclone CLI"。
#
# TODO(生产替换)：真正的工具链应指向预编译单文件二进制
# （见 tools/repositories.bzl），shim 仅供本机开发联调。
#
# 用法：bazel test --test_env=CYCLONE_MVP_HOME=/path/to/cyclone-mvp //...
set -euo pipefail

: "${CYCLONE_MVP_HOME:?请通过 --test_env=CYCLONE_MVP_HOME=<cyclone-mvp 路径> 指定}"

export PYTHONPATH="$CYCLONE_MVP_HOME${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m cyclone "$@"
