"""cyclone 工具链：多平台 CLI 的解析与注入。

设计要点：
- 规则（cyclone_test）不直接引用二进制，只声明需要 toolchain_type；
- Bazel 按执行平台（exec platform）自动撮合对应的 CLI 二进制；
- 本地开发可用 examples 里的 shim 工具链（包 python -m cyclone），
  生产环境用 tools/repositories.bzl 下载的预编译二进制（带 SHA-256）。
"""

CycloneInfo = provider(
    doc = "Cyclone Core CLI 的位置信息",
    fields = {
        "cli": "File: cyclone 可执行文件（单文件二进制或 shim 脚本）",
    },
)

def _cyclone_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        cyclone = CycloneInfo(cli = ctx.executable.cli),
    )]

cyclone_toolchain = rule(
    implementation = _cyclone_toolchain_impl,
    attrs = {
        "cli": attr.label(
            executable = True,
            cfg = "exec",
            doc = "cyclone CLI 可执行目标（单文件二进制或 sh_binary 包装）",
        ),
    },
    doc = "声明某平台上的 cyclone CLI 工具链",
)

def declare_cyclone_toolchains():
    """为三个主流 exec 平台声明 toolchain（在 tools/BUILD.bazel 中调用）。

    每个 toolchain 指向 repositories.bzl 下载的对应平台二进制。
    """
    PLATFORMS = {
        "linux_amd64": ["@platforms//os:linux", "@platforms//cpu:x86_64"],
        "linux_arm64": ["@platforms//os:linux", "@platforms//cpu:aarch64"],
        "darwin_arm64": ["@platforms//os:macos", "@platforms//cpu:aarch64"],
    }
    for name, constraints in PLATFORMS.items():
        cyclone_toolchain(
            name = "cyclone_toolchain_" + name,
            cli = "@cyclone_cli_" + name + "//:cyclone",
        )
        native.toolchain(
            name = "toolchain_" + name,
            toolchain_type = ":toolchain_type",
            toolchain = ":cyclone_toolchain_" + name,
            exec_compatible_with = constraints,
        )
