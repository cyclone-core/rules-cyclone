#!/usr/bin/env bash
# cyclone_test 运行器模板（expand_template 生成，@VAR@ 会被替换）
#
# 职责：
# - 在可写的 TEST_TMPDIR 中执行（runfiles 树只读；数据集确定性生成落在这里）
# - JUnit → $XML_OUTPUT_FILE（Bazel 契约）
# - 证据链 → $TEST_UNDECLARED_OUTPUTS_DIR/evidence（随测试日志归档）
set -euo pipefail

WORK="${TEST_TMPDIR:-$(mktemp -d)}/cyclone_work"
mkdir -p "$WORK/data"
cd "$WORK"

EVIDENCE_DIR="${TEST_UNDECLARED_OUTPUTS_DIR:-$WORK/outputs}/evidence"
mkdir -p "$EVIDENCE_DIR"

# short_path 解析：主仓库文件在 $TEST_SRCDIR/$TEST_WORKSPACE/ 下，
# 外部仓库文件 short_path 以 "../<repo>/" 开头，位于 $TEST_SRCDIR/ 下
rl() {
    case "$1" in
        ../*) printf '%s/%s' "$TEST_SRCDIR" "${1#../}" ;;
        *)    printf '%s/%s/%s' "$TEST_SRCDIR" "$TEST_WORKSPACE" "$1" ;;
    esac
}

# data attr 文件按 workspace 相对路径链接进来：csv:///mcap:// 等
# 相对路径数据集在工作目录下可解析（无 data 时下行展开为空；须在 rl 定义之后）
@DATA_LINKS@

"$(rl '@CYCLONE@')" run \
    "$(rl '@SCENARIO@')" \
    --out "$EVIDENCE_DIR" \
    --junit-xml "${XML_OUTPUT_FILE:-$WORK/junit.xml}" \
    @EXTRA_ARGS@
