"""bzlmod 模块扩展：在 MODULE.bazel 的 use_extension 中触发 CLI 下载。"""

load(":repositories.bzl", "cyclone_repositories")

def _cyclone_extension_impl(_ctx):
    cyclone_repositories()

cyclone = module_extension(implementation = _cyclone_extension_impl)
