# DSH Web Profile

本仓库用于同步我的 DeepSeek Harness（DSH）`web` profile 配置与插件列表。

> **注意**：这不包含 DSH 源码本身。DSH 源码见 [deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)；本仓库只保存 profile 层的依赖、补丁与加载规则。

---

## 当前已装插件

| 插件 | 来源 | 说明 |
|---|---|---|
| `@linxin666/dsh-web-all` | npm | web 插件合集 |
| `dsh-deja` | npm | 跨会话记忆/Deja 插件 |
| `dsh-find-plugin` | npm | 插件查找 |
| `dsh-token-stats` | `github:H1a3x/dsh-token-stats` | 浮动 Token 用量统计面板 |
| `@yuxianglin/dsh-bridge-browser` | 本地 link | DSH 浏览器桥接(依赖 `~/.dsh/dsh-browser`,见下方注意事项) |

---

## 如何使用

### 1. 在新机器上恢复这个 profile

先确保已经安装好 DSH 并能正常运行，然后执行：

```bash
# 克隆本仓库到 DSH 的 web profile 目录
git clone git@github.com:PKM-Bai/dsh-web-profile.git ~/.dsh/profiles/web

# 进入目录安装依赖
pnpm install

# 重启 DSH 并刷新浏览器页面
```

> Windows 用户请把 `~/.dsh/profiles/web` 替换为 `C:\Users\<用户名>\.dsh\profiles\web`。

### 2. 日常更新后同步到本仓库

当你在 DSH 中安装/卸载/更新插件后，本仓库的 `package.json`、`pnpm-lock.yaml` 或 `cordis.patch.yml` 会发生变化。同步方法：

```bash
cd ~/.dsh/profiles/web

# 查看变更
git status

# 提交并推送
git add -A
git commit -m "update profile plugins"
git push
```

### 3. 从本仓库拉取最新配置

如果你在另一台机器修改了插件并 push，在当前机器执行：

```bash
cd ~/.dsh/profiles/web
git pull
pnpm install
# 然后重启 DSH
```

---

## 仓库中包含的文件

| 文件 | 作用 |
|---|---|
| `package.json` | profile 依赖清单，记录所有已装插件 |
| `pnpm-lock.yaml` | 精确锁定插件版本，保证不同机器安装一致 |
| `pnpm-workspace.yaml` | pnpm workspace 配置 |
| `cordis.patch.yml` | DSH 加载器补丁，控制插件如何被注入/加载 |
| `cordis.yml` | profile 根配置（默认空列表） |
| `.gitignore` | 忽略 `node_modules/` 等无需版本控制的文件 |

---

## DSH 桌面版启动器

随本仓库同步的桌面快捷启动工具:一键后台启动 DSH 服务,并以 Chrome 独立应用窗口打开 Web 界面(无地址栏/标签页,类似桌面 App)。代码在 `desktop-launcher/` 目录。

在每台电脑上安装:

```powershell
cd ~/.dsh/profiles/web/desktop-launcher
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

- 脚本会自动识别 DSH 部署目录并写入本机配置(`~/.dsh/desktop-launcher/machine-config.ps1`,不入库);若路径不同,加参数 `-RepoPath "你的部署路径"`。
- 安装后桌面出现「DSH 桌面版」「DSH 停止服务」两个快捷方式。
- 详细说明见 [`desktop-launcher/README.md`](desktop-launcher/README.md)。

---

## 历史会话同步(可选)

DSH 的历史会话、任务台账、附件可通过私有仓库 [PKM-Bai/dsh-sessions](https://github.com/PKM-Bai/dsh-sessions)(**私有**,含私人对话)在两台电脑间同步。同步脚本在本仓库 `tools/sync-sessions.ps1`:

```powershell
# 换机前: 把本机会话推到远端 (本机缓冲仓库: E:\DSH-Sessions, 放 E 盘省 C 盘空间)
powershell -NoProfile -ExecutionPolicy Bypass -File ~\.dsh\profiles\web\tools\sync-sessions.ps1 -Push

# 换机后: 把远端会话拉到本机
powershell -NoProfile -ExecutionPolicy Bypass -File ~\.dsh\profiles\web\tools\sync-sessions.ps1 -Pull
```

- 约定:同一时间只在一台电脑运行 DSH;建议先停止 DSH 服务再同步(脚本会提示,`-Force` 可跳过)。
- 缓冲仓库路径可用 `-RepoPath` 覆盖(如公司机器放 `D:\DSH-Sessions`)。
- 同步内容:`sessions/`、`storages/`、`task-board/`、`attachments/`。

---

## 注意事项

- **不要提交 `node_modules/`**：本仓库只保存配置，插件由 `pnpm install` 还原。
- **敏感信息**：如果以后在 `cordis.patch.yml` 或 `cordis.yml` 中写入了 API key、token 等敏感内容，请谨慎提交；必要时改用环境变量或本地覆盖文件。
- **重启 DSH**：安装/更新/修改 client 插件后，通常需要**重启 DSH 服务并刷新浏览器页面**才能生效。
- **`@yuxianglin/dsh-bridge-browser` 是本地 link 依赖**：`package.json` 中记录的是 `link:C:/Users/Admin/.dsh/dsh-browser/...`。换机器后如果路径不同,请把该行改为新机器上的实际路径(或相对路径 `link:../../dsh-browser/packages/browser/bridge-browser`,要求 `dsh-browser` 安装在 `~/.dsh/dsh-browser`),再执行 `pnpm install`。

---

## 相关仓库

- DSH 官方源码：[deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)
- 我的 DSH 源码 fork：[PKM-Bai/pkm-bai-deepseek-harness](https://github.com/PKM-Bai/pkm-bai-deepseek-harness)
