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
        "cli": "File: cyclone 可执行文件（onedir 内或 shim 脚本）",
        "files": "depset[File]: 运行所需全部文件（onedir 发行版为整个解压树；shim 仅 cli 本身）",
    },
)

def _cyclone_toolchain_impl(ctx):
    # shim 只有 cli；onedir 发行版 cli ∈ dist glob，depset 自动去重
    files = depset([ctx.file.cli] + ctx.files.dist)
    return [platform_common.ToolchainInfo(
        cyclone = CycloneInfo(cli = ctx.file.cli, files = files),
    )]

cyclone_toolchain = rule(
    implementation = _cyclone_toolchain_impl,
    attrs = {
        # 注意不能用 executable=True：下载仓库里的文件是 source file，
        # executable 属性只接受规则的 executable 输出。可执行位由
        # http_archive 解 tar 保留（shim 侧由 examples 的 genrule 置位）。
        "cli": attr.label(
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
            doc = "cyclone CLI 可执行文件（onedir 树内或 shim 脚本）",
        ),
        "dist": attr.label_list(
            allow_files = True,
            cfg = "exec",
            doc = "onedir 发行版的全部文件（_internal 等）；shim 留空",
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
            # tar.gz 解开为 cyclone/ 目录：cli 是树内文件，dist 带整树
            cli = "@cyclone_cli_" + name + "//:cyclone/cyclone",
            dist = ["@cyclone_cli_" + name + "//:cyclone_dist"],
        )
        native.toolchain(
            name = "toolchain_" + name,
            toolchain_type = ":toolchain_type",
            toolchain = ":cyclone_toolchain_" + name,
            exec_compatible_with = constraints,
        )
