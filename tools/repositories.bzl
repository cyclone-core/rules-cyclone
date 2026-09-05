"""cyclone CLI 预编译二进制的下载定义。

发布渠道：`cyclone-core/rules-cyclone` 的 GitHub Release——公开仓库的资产
可匿名下载（社区版免费获客钩子的前提；商业版二进制另行鉴权托管）。
产物为 PyInstaller **onedir** 的 tar.gz（形态决策见引擎仓 packaging/README.md；
勿改回 onefile：macOS 对其每次启动重做安全评估，实测 52s/次）。

SHA-256 已按 v0.1.0 Release 的 .sha256 sidecar 固定；升级版本时
同步更新 _CYCLONE_VERSION 与三个哈希（取自引擎仓 CI 产出的 sidecar）。
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_CYCLONE_VERSION = "0.1.0"

# v0.1.0 Release 资产：cyclone-darwin-arm64.tar.gz / cyclone-linux-amd64.tar.gz / ...
_URL = "https://github.com/cyclone-core/rules-cyclone/releases/download/v{v}/cyclone-{p}.tar.gz"

_PLATFORMS = ["linux_amd64", "linux_arm64", "darwin_arm64"]

# 取自 v0.1.0 Release 各 tar.gz 的 .sha256 sidecar（CI 产出，勿用本地构建值）
_SHA256 = {
    "linux_amd64": "bd966eb84f831e97e6a56ee1f8e055822481bfac82b337b1de1a9508dcf20cf4",
    "linux_arm64": "1ac1495688f222ea8d6855b3ace5400b83ef14088035a2a55628314f6367d09f",
    "darwin_arm64": "2fd559f3b02daf12cce71d7b73a0f440165fee3a13194f997cef6e7b54766a86",
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
