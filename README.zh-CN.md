# DMS 插件

[English](README.md)

`oai404iao/dms-plugins` 是维护插件源码的单仓库。`plugins/` 下每个目录都是
独立的 DMS 插件，不需要嵌套 Git 仓库。

| 组件 | 职责 |
| --- | --- |
| `plugins/lyrics` | 共享双语歌词守护插件，本地维护版本 `0.4.0-local.1` |
| `plugins/dankTodo` | 本地维护的 Dank Todo `1.3.0-local.1`：中文、树形子任务、时间与暂停；请先读[已知风险](docs/todo-audit.md) |
| `scripts/dms-media-lyrics` | 锁定版本的原生媒体栏与媒体页覆盖层 |
| `scripts/prepare-dms-media-lyrics.py` | 离线准备独立 shell 副本 |
| `bin/dms-with-lyrics` | 版本匹配的启动器，不匹配时回退原版 DMS |

## 所有权与来源

本仓库管理插件源码、覆盖层、启动器、安装器和测试。Dotfiles/chezmoi 管理桌面
配置，不再保留另一份这些源码。DMS 启用状态、顶栏布局、偏好、插件锁文件、
缓存、凭据和 `~/.config/dank-todo/todos.json` 属于机器本地状态，不应提交。
上游许可证保留，详见[来源与许可证](docs/provenance.md)。Todo 在本地继续维护，
用法及数据格式见[插件说明](plugins/dankTodo/README.md)。

歌词守护插件使用播放元数据查询网易云和 LRCLIB，不需要 API 密钥或 AI 服务。
供应商可用性和翻译覆盖率不作保证。它不是独立顶栏组件，而是通过准备好的覆盖层
集成到原生媒体界面。中文设置翻译不等于自动翻译歌词。

## 本地安装

需要 Python 3、DMS 和长期保留的仓库目录。已审核的歌词覆盖层仅支持
**DMS v1.6.2、v1.6.3**，其他版本会主动拒绝。将仓库克隆到开发目录，
不要放在 DMS 插件目录内部。在仓库根目录运行：

```sh
sh tests/check-source.sh
python3 scripts/install.py --dry-run
python3 scripts/install.py
```

安装器仅建立以下链接：

- `$XDG_CONFIG_HOME/DankMaterialShell/plugins/lyrics`（默认 `~/.config/...`）；
- `$XDG_CONFIG_HOME/DankMaterialShell/plugins/dankTodo`；
- `~/.local/bin/dms-with-lyrics`。

原有文件、目录（含 `.git`）和软链接会完整移动到
`~/.local/state/agents/tmp/dms-plugins-install.*` 下新建的 0700 私有目录。
安装器打印所有备份路径，拒绝跨文件系统备份重命名，可重复运行，并拒绝与自身
源码仓库重叠的目标。它不删除备份或数据，不下载代码，不改变偏好，不准备覆盖层，
不启用插件，也不重启 DMS。失败可能留下部分安装结果；重试前检查输出并保留备份。
安装后不要移动仓库。条件允许时，请在启动 DMS 会话前安装。

从已有 dotfiles 配置迁移时，应先按原仓库迁移说明解除旧源码管理，否则后续 apply
可能覆盖这些链接。安装器不会修改 chezmoi 或 Niri 配置。会话 PATH 应包含
`~/.local/bin`。

## 准备歌词覆盖层

使用已安装、受支持 DMS 版本的可信、完整、未经修改的 shell 解包目录。
原版 DMS 运行时可通过 `qs list --all` 找到路径。不要输入已经打过覆盖层的目录：

```sh
python3 scripts/prepare-dms-media-lyrics.py /path/to/pristine/extracted/dms-shell
```

脚本检查版本以及 `shell.qml` 和五个替换组件的精确哈希，复制完整目录，并生成
`$XDG_DATA_HOME/dms-media-lyrics/current`（默认 `~/.local/share/...`）。
它不修改已安装的软件包或只读解包目录。哈希是兼容性保护，不是完整源码真实性
验证。生成目录及准备工作区保留在 Git 外，不要通过篡改版本标记绕过检查。

把会话中的 `dms run` 改为 `dms-with-lyrics run`，保留已有参数。
不要额外运行第二个 DMS 实例或服务。启动器仅在 `dms version` 匹配时使用准备好的
目录，否则使用原版 DMS。会话配置和重启仍需手工处理，并在解锁状态下进行。

## 启用、使用与更新

DMS 运行时：

```sh
dms ipc call plugin-scan scan
dms ipc call plugins enable lyrics
dms ipc call plugins enable dankTodo
```

等待扫描完成再启用。在设置 → DankBar 中将 **Dank Todo** 加到一个顶栏分区。
不要把歌词守护插件当作顶栏组件添加。偏好仍由 DMS 保存。Todo 默认数据路径为
`$XDG_CONFIG_HOME/dank-todo/todos.json`，可在插件设置中修改。请将 Todo 视为实验性
插件，尤其留意多屏情况，并独立备份数据。

更新并审核此 Git 仓库，运行离线检查，再明确执行重载：

```sh
dms ipc call plugins reload lyrics
dms ipc call plugins reload dankTodo
```

如果导入的 JavaScript 仍被缓存，请在解锁状态下手工重启 DMS。覆盖层更新需要从
原始源码重新准备，并通过启动器手工重启会话。不要对这些维护目标执行注册表
`dms plugins install`、`update` 或 `restore`：虽然保留了 `lyrics`、`dankTodo`
ID，但源码由此仓库而非注册表管理。安装器不会改写已有锁文件条目。

## 验证

`sh tests/check-source.sh` 运行清单与精确文件 inventory 检查、隔离的安全安装测试、
歌词 JavaScript 测试、无界面的 Qt 6 QML 测试（含 Todo 树形、时间和状态回归）、
覆盖层准备及启动器回退测试。
全部离线，不请求真实歌词供应商、不调用模型、不改变桌面、不发送通知。
缺少 Node 或 Qt 6 时对应测试会明确跳过。Python 和 QML 测试工作区保留在
`~/.local/state/agents/tmp`。这些测试不代表 Todo 运行可靠性，也不是完整真实会话测试。
