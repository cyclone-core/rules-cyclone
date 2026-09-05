"""cyclone CLI 预编译二进制的下载定义。

TODO(发布前填充)：
1. 二进制由引擎仓库 packaging/build_binary.sh 产出（PyInstaller **onedir** +
   tar.gz——不要用 onefile 单文件：macOS 对其每次启动重做安全评估，实测
   52s/次；详见引擎仓库 packaging/README.md）；
2. 填入真实 url 与 sha256，http_file 相应换成 http_archive（tar.gz 解开为
   cyclone/ 目录，cli 指向 cyclone/cyclone，可执行位由 tar 保留）；
3. 需要 license 鉴权时改用 netrc 或自定义 repository_rule。

当前为占位定义：URL/SHA-256 未填，工具链不会被解析，故不触发下载。
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

_CYCLONE_VERSION = "0.1.0"

# TODO: 替换为真实发布地址与哈希
_URLS = {
    "linux_amd64": "https://releases.example.com/cyclone/{v}/cyclone-linux-amd64".format(v = _CYCLONE_VERSION),
    "linux_arm64": "https://releases.example.com/cyclone/{v}/cyclone-linux-arm64".format(v = _CYCLONE_VERSION),
    "darwin_arm64": "https://releases.example.com/cyclone/{v}/cyclone-darwin-arm64".format(v = _CYCLONE_VERSION),
}

_SHA256 = {
    "linux_amd64": "0" * 64,  # TODO
    "linux_arm64": "0" * 64,  # TODO
    "darwin_arm64": "0" * 64,  # TODO
}

def cyclone_repositories():
    """下载各平台 cyclone CLI（bzlmod 扩展中调用）。"""
    for platform, url in _URLS.items():
        http_file(
            name = "cyclone_cli_" + platform,
            url = url,
            sha256 = _SHA256[platform],
            executable = True,
            downloaded_file_path = "cyclone",
        )
