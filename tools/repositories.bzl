"""cyclone CLI 预编译二进制的下载定义。

TODO(发布前填充)：
1. 把 cyclone CLI 打成单文件二进制（PyInstaller / 将来的 C++ 内核静态链接版），
   上传到 release 托管（GitHub Releases / 内网制品库，建议带鉴权——
   这也是 license 控制的挂载点）；
2. 填入真实 url 与 sha256；
3. 需要 license 鉴权时改用 http_file 的 netrc 或自定义 repository_rule。

每个平台一个 http_file，文件名固定为 cyclone，可执行权限由
toolchain 引用处的 executable=True 保证。
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
