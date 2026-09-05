"""cyclone CLI 预编译二进制的下载定义。

发布渠道：`cyclone-core/rules-cyclone` 的 GitHub Release——公开仓库的资产
可匿名下载（社区版免费获客钩子的前提；商业版二进制另行鉴权托管）。
产物为 PyInstaller **onedir** 的 tar.gz（形态决策见引擎仓 packaging/README.md；
勿改回 onefile：macOS 对其每次启动重做安全评估，实测 52s/次）。

SHA-256 待回填：三平台产物由引擎仓 CI（build-binary.yml）产出后统一填入；
填齐前 MODULE.bazel 不默认 register_toolchains，下载不会被触发。
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_CYCLONE_VERSION = "0.1.0"

# v0.1.0 Release 资产：cyclone-darwin-arm64.tar.gz / cyclone-linux-amd64.tar.gz / ...
_URL = "https://github.com/cyclone-core/rules-cyclone/releases/download/v{v}/cyclone-{p}.tar.gz"

_PLATFORMS = ["linux_amd64", "linux_arm64", "darwin_arm64"]

# TODO(release)：CI 产出三平台 tar.gz 后回填真实哈希
_SHA256 = {
    "linux_amd64": "0" * 64,
    "linux_arm64": "0" * 64,
    "darwin_arm64": "0" * 64,
}

# tar.gz 解开为 cyclone/ 目录（可执行位由 tar 保留）：cli 文件 + 整树 filegroup
# （_internal 依赖必须随行进 runfiles，onedir 才能跑）
_BUILD = """
package(default_visibility = ["//visibility:public"])
exports_files(["cyclone/cyclone"])
filegroup(
    name = "cyclone_dist",
    srcs = glob(["cyclone/**"]),
)
"""

def cyclone_repositories():
    """下载各平台 cyclone CLI（bzlmod 扩展中调用）。"""
    for plat in _PLATFORMS:
        http_archive(
            name = "cyclone_cli_" + plat,
            url = _URL.format(v = _CYCLONE_VERSION, p = plat.replace("_", "-")),
            sha256 = _SHA256[plat],
            build_file_content = _BUILD,
        )
