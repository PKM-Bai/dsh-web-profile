# DSH 桌面版启动器 (Desktop Launcher)

把 DeepSeek Harness 的 Web 界面变成类似桌面 App 的独立窗口(Chrome `--app` 模式,无地址栏/标签页),并支持**一键后台启动服务**。

随 `dsh-web-profile` 仓库同步,家用/公司两台电脑共用一套代码。

## 文件说明

| 文件 | 作用 |
|---|---|
| `start-dsh.ps1` | 主启动:服务未运行则后台启动 → 等待就绪 → 打开独立窗口 |
| `stop-dsh.ps1` | 停止 DSH 服务 |
| `install.ps1` | 每台电脑运行一次:生成机器配置 + 隐藏窗口包装 + 桌面快捷方式 |
| `dsh-app.ico` | 快捷方式图标 |

## 安装(每台电脑)

1. 先按仓库根目录 README 把本仓库克隆到 `~/.dsh/profiles/web` 并 `pnpm install`。
2. 打开 PowerShell,执行:

```powershell
cd ~/.dsh/profiles/web/desktop-launcher
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

- 若 DSH 部署目录(含 `apps\cli\src\bin.ts` 的目录)不是默认的 `E:\GitProject\pkm-bai-deepseek-harness`,脚本会提示输入,或直接传参:
  `powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -RepoPath "你的部署路径"`
- 完成后桌面出现两个快捷方式:
  - **DSH 桌面版**:一键启动并打开独立应用窗口(重复点击只激活已有窗口)
  - **DSH 停止服务**:停止后台服务

## 工作原理

- 快捷方式 → `wscript.exe` → `launch-dsh.vbs`(隐藏窗口)→ `start-dsh.ps1`
- `start-dsh.ps1` 用独立 Chrome 配置目录 `%LOCALAPPDATA%\DSH-App` 打开
  `chrome.exe --app=http://127.0.0.1:3080`,因此即使普通 Chrome 正开着,也保证独立窗口。
- 机器相关路径(DSH 部署目录)写在 `~/.dsh/desktop-launcher/machine-config.ps1`(由 install.ps1 生成,不入库),可用环境变量 `DSH_REPO` 覆盖。
- 服务日志在 `~/.dsh/desktop-launcher/logs/`。

## 注意事项

- **安全软件**:部分安全软件会删除"powershell + 隐藏窗口"特征的快捷方式。本方案把隐藏逻辑放在 `.vbs` 内、快捷方式只指向 `wscript.exe`,可规避;若仍被删除,请把桌面快捷方式加入安全软件白名单。
- 独立窗口使用独立 Chrome 配置目录,与日常 Chrome 的登录态/扩展互不影响(DSH 桥接扩展会自动挂载)。
