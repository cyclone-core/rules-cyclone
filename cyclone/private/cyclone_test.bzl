"""cyclone_test 规则实现：把 Cyclone Core 用例挂进 bazel test。

Bazel 测试契约（本规则满足的三条）：
1. 退出码：0 = PASS，非 0 = FAIL（cyclone CLI 原生满足）；
2. JUnit：写入 $XML_OUTPUT_FILE → Bazel 自动收集进 BES / CI 看板；
3. 输入进图：scenario + data + CLI 全部进 runfiles → 输入哈希完整，
   确定性用例可安全命中远程缓存（cached PASS 是内容寻址的 PASS）。

证据链落点：$TEST_UNDECLARED_OUTPUTS_DIR/evidence/
（Bazel 会把该目录随 test.log 一起归档——失败现场快照不丢失）
"""

def _cyclone_test_impl(ctx):
    toolchain = ctx.toolchains["@rules_cyclone//tools:toolchain_type"].cyclone
    cli = toolchain.cli

    scenario = ctx.files.scenario[0]

    # 运行期输入：CLI + 场景 + 回放数据（可选）
    runfiles = ctx.runfiles(files = [cli, scenario] + ctx.files.data)

    # data 文件按 workspace 相对路径链接进 $WORK：csv:///mcap:// 等
    # 相对路径数据集在 runner 的 CWD 下即可解析（无 data 时展开为空行）
    data_links = "\n".join([
        'mkdir -p "$(dirname "{p}")" && ln -sf "$(rl "{p}")" "{p}"'.format(
            p = f.short_path)
        for f in ctx.files.data
    ])

    runner = ctx.actions.declare_file(ctx.label.name + "_runner.sh")
    ctx.actions.expand_template(
        template = ctx.file._runner_tpl,
        output = runner,
        is_executable = True,
        substitutions = {
            "@CYCLONE@": cli.short_path,
            "@SCENARIO@": scenario.short_path,
            "@DATA_LINKS@": data_links,
            "@EXTRA_ARGS@": " ".join(ctx.attr.extra_args),
        },
    )

    return [DefaultInfo(executable = runner, runfiles = runfiles)]

cyclone_test = rule(
    implementation = _cyclone_test_impl,
    test = True,
    attrs = {
        "scenario": attr.label(
            allow_single_file = [".yaml", ".yml"],
            mandatory = True,
            doc = "Cyclone 场景 DSL（YAML）：用例、故障注入、断言一体",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "回放数据 clip（可选；缺省时由用例按 seed 确定性生成）",
        ),
        "extra_args": attr.string_list(
            doc = "透传给 cyclone CLI 的额外参数",
        ),
        "_runner_tpl": attr.label(
            default = "//cyclone/private:runner.sh.tpl",
            allow_single_file = True,
        ),
    },
    toolchains = ["@rules_cyclone//tools:toolchain_type"],
    doc = """在 bazel test 中运行一个 Cyclone Core 确定性测试用例。

    示例：
        cyclone_test(
            name = "aeb_camera_dropout_regression",
            scenario = "scenarios/aeb_dropout.yaml",
            data = ["clips/cut_in_0432.csv"],
            size = "medium",
        )

    涉及真实硬件（CAN 卡 / 台架）的用例请打：
        tags = ["manual", "exclusive", "local", "no-cache"]
    防止被远程执行与并行调度干扰；no-cache 必须带——can:// 用例的
    实测时序字段（uds_resp_ms / can_rx_*）进 sidecar 日志后主 digest
    可内容寻址，但判定本身仍依赖总线时序，不能进任何缓存。
    """,
)
