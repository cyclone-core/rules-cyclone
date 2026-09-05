# rules_cyclone

Cyclone Core 的 Bazel 规则包：把确定性 XiL 测试变成 `bazel test` 的一等公民。

> **状态：pre-release（开发中）**。BCR 收录与预编译 CLI 发布在路线图上；
> 当前 examples 需配合一份本地 cyclone 引擎检出运行（见「本地验证」节）。

## 给使用者的三行接入

```python
# MODULE.bazel
bazel_dep(name = "rules_cyclone", version = "0.1.0")
register_toolchains("@rules_cyclone//tools:all")   # 使用预编译 CLI（发布后）
```

```python
# BUILD.bazel
load("@rules_cyclone//cyclone:defs.bzl", "cyclone_test")

cyclone_test(
    name = "aeb_camera_dropout_regression",
    scenario = "scenarios/aeb_dropout.yaml",
    size = "medium",
)
```

然后 `bazel test //...` —— Cyclone 用例与单元测试共用构建图、远程缓存与 CI 看板。

## 工作原理（三条 Bazel 测试契约）

1. **退出码**：cyclone CLI 判定 PASS 退出 0，FAIL 退出非 0；
2. **JUnit**：结果写入 `$XML_OUTPUT_FILE`，Bazel 自动收集进 BES/看板，
   XML 的 `<properties>` 携带 case_hash / seed / 日志 SHA-256 摘要——
   每条 CI 记录可回溯到用例版本与原始数据；
3. **输入进图**：scenario + data + CLI 全部进 runfiles，输入哈希完整，
   确定性用例的 `(cached) PASS` 是内容寻址的 PASS。

证据链（用例哈希、日志摘要、失败现场快照、完整报告）落在
`$TEST_UNDECLARED_OUTPUTS_DIR/evidence/`，随测试日志一并归档；其中
`*_manifest.json` 是自描述清单（case_hash / seed / digest / verdict /
产物相对名），BES 后端或 CI 脚本读一份 JSON 即可索引证据。

## 接 BES（Build Event Service）

规则包不绑定任何厂商：把端点指向任一 BES 后端（BuildBuddy / EngFlow /
自建）即可。仓库根附推荐配置 `bes.bazelrc`，`try-import` 或复制后改端点：

```bash
bazel test --config=bes //...
```

JUnit `<properties>` 携带 case_hash / seed / log_digest_sha256——看板上
任何一条 FAIL 都能凭 case_hash + digest 回溯到用例版本与原始证据日志。

两个坑（CI 脚本必看）：

1. **退出码不可信**：BES 上传失败时 Bazel 可能把进程退出码改写成
   `PERSISTENT_BUILD_EVENT_SERVICE_UPLOAD_ERROR`，盖掉真实结果
   （[bazel#25756](https://github.com/bazelbuild/bazel/issues/25756)）。
   判成败解析 BEP 的 `BuildFinished.exitCode`，别看进程退出码。
2. **证据取回依赖远程缓存**：不配 `--remote_cache` 时 BEP 里的 test.log /
   outputs 归档是执行机本地 `file://` URI，BES 服务端够不着；配缓存后变
   `bytestream://`，证据链才可远程审计。

### flaky 语义的分工

| 层 | 机制 | 管什么 |
|---|---|---|
| Bazel | `flaky = True` / `--runs_per_test` | 基础设施抖动（调度/环境噪声）；每次 attempt 是独立 `TestResult` 事件，BES 后端聚合 flaky 率 |
| cyclone | Wilson CI / SPRT | 信号级统计（检出率/误报率的显著性判定），发生在一次运行内部 |

原则：**Bazel 管"这次运行本身可不可信"，cyclone 管"这次运行里的信号达
不达标"**。别把 `--runs_per_test` 当统计显著性工具（那是 SPRT 的活）；
cyclone 也不内置重试——重试交给 Bazel，两次 attempt 在 BES 各自留痕，
flaky 画像才真实。

## 目录结构

```
cyclone/            公共入口 defs.bzl 与规则实现
  private/          cyclone_test.bzl + runner.sh.tpl（不承诺稳定）
tools/              工具链类型、预编译 CLI 下载（repositories.bzl）、bzlmod 扩展
examples/           可运行示例：本地 shim 工具链驱动 cyclone 引擎源码（联调用）
```

## 本地验证（shim 工具链，无需发布二进制）

```bash
cd examples
bazel test --test_env=CYCLONE_MVP_HOME=/path/to/cyclone-engine \
    --test_env=PATH="/path/to/cyclone-engine/.venv/bin:$PATH" //:aeb_hello_test
```

shim 用 `python3 -m cyclone` 驱动**一份独立的 cyclone 引擎源码检出**（引擎仓库
另行分发），需保证 `python3` 环境已装引擎的 `requirements.txt` 依赖（上方
`--test_env=PATH` 把引擎检出的 venv 排最前即可）。
待预编译社区版 CLI 发布后，examples 将默认改用二进制工具链，无需引擎源码。

## 缓存纪律：不需要 bazel clean

Bazel 的设计前提是**增量永远正确**：每个 action 的输入都进哈希图，输入没变
⇒ 输出复用。`(cached) PASSED` 是特性而非偷懒——日常反复 `bazel test` 即可，
`bazel clean` 只会让你失去全部缓存收益。它仅有的正当用途：清磁盘空间、
排查 Bazel 自身怪问题、换 Bazel 大版本。

**一个例外——shim 开发流**：shim 经环境变量 `CYCLONE_MVP_HOME` 引入引擎源码，
引擎代码不在哈希图里。改了引擎代码后直接重跑会得到 `(cached) PASSED`
（新代码根本没执行）。此时用精准开关强制重跑，不要 clean：

```bash
bazel test --cache_test_results=no //:aeb_hello_test   # 构建缓存仍保留
```

预编译二进制工具链（`http_file` + SHA-256）接上后，引擎版本本身成为图节点，
此坑自然消失。

## 发布前待办（骨架中标记 TODO 处）

- [ ] cyclone CLI 打单文件二进制（PyInstaller；远期 C++ 内核静态链接版）
- [x] `tools/repositories.bzl`：真实下载 URL（本仓 Release）已填；**SHA-256 待**
      引擎仓 CI（build-binary.yml）产出三平台 tar.gz 后回填，回填后即可在
      MODULE.bazel 默认注册工具链（商业版二进制另行鉴权托管——license 挂载点）
- [ ] 已知事项：首次运行下载的 onedir 树有一次性安全评估（macOS 实测首跑
      ~20s，之后 ~0.3s）——`bazel test` 首跑超时属预期，重跑即过
- [ ] hermetic 自查：CLI 执行不读系统时钟/环境/绝对路径（cached PASS 叙事的地基）
- [ ] 涉及真实硬件的用例打 `tags = ["manual", "exclusive", "local", "no-cache"]`
      （`no-cache` 必须带：can:// 用例的 digest 含实测时序，即使本地缓存也是脏的）
- [ ] 向 BCR（Bazel Central Registry）提 PR 或建私有 registry

## License

[Apache-2.0](LICENSE)。规则包本身自由使用；cyclone 引擎（CLI 二进制）的
许可条款随二进制分发另行约定。
