# ============================================================
#  DSH 桌面版启动器 (DeepSeek Harness Desktop Launcher)
#  便携版: 随 dsh-web-profile 仓库同步, 家用/公司两台电脑共用
#  流程: 1) 服务未运行则后台启动  2) 等待就绪  3) Chrome 独立窗口
# ============================================================
$ErrorActionPreference = 'Stop'

# ---------- 路径解析 (跨机器) ----------
# DSH_HOME: 环境变量优先, 否则 ~/.dsh
$DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }

# 机器配置 (由 install.ps1 在每台机器上生成, 存放 DSH 部署目录等)
$MachineCfg = Join-Path $DshHome 'desktop-launcher\machine-config.ps1'
if (Test-Path $MachineCfg) { . $MachineCfg }

# DSH 部署目录 (含 apps\cli\src\bin.ts): 环境变量 > 机器配置 > 默认值
$Repo = $env:DSH_REPO
if (-not $Repo) { $Repo = $DSH_REPO }
if (-not $Repo) { $Repo = 'E:\GitProject\pkm-bai-deepseek-harness' }

$Url        = 'http://127.0.0.1:3080'                    # dsh Web 地址
$Port       = 3080                                       # 监听端口
$LogDir     = Join-Path $DshHome 'desktop-launcher\logs'
$Chrome     = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$MsEdge     = "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"

# 独立应用窗口专用配置目录: 保证即使普通 Chrome 在运行, 也以独立窗口打开
$AppProfile = Join-Path $env:LOCALAPPDATA 'DSH-App'
# DSH 浏览器桥接扩展 (存在则挂载到独立窗口)
$Extension  = Join-Path $DshHome 'browser-extension'

# ---------- 工具函数 ----------
function Show-Msg([string]$Title, [string]$Text) {
    $ws = New-Object -ComObject WScript.Shell
    [void]$ws.Popup($Text, 0, $Title, 48 + 4096)   # 48=警告图标, 4096=系统置顶
}

function Test-PortListen {
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Open-AppWindow {
    # 1) 已有同 URL 的独立窗口 -> 直接激活它,避免重复开窗
    $appMarker = "--app=$Url"
    $existing = Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine.Contains($appMarker) } |
        Select-Object -First 1
    if ($existing) {
        $proc = Get-Process -Id $existing.ProcessId -ErrorAction SilentlyContinue
        if ($proc -and $proc.MainWindowHandle -ne 0) {
            $ws = New-Object -ComObject WScript.Shell
            [void]$ws.AppActivate($existing.ProcessId)
            return
        }
    }
    # 2) 打开新独立窗口: Chrome 优先, Edge 其次, 最后回退默认浏览器
    #    使用专用 user-data-dir, 避免被已运行的 Chrome 实例接管成普通标签页
    $browserArgs = @(
        "--app=$Url",
        "--user-data-dir=$AppProfile",
        '--no-first-run',
        '--no-default-browser-check',
        '--start-maximized'
    )
    if (Test-Path $Extension) {
        $browserArgs += "--load-extension=$Extension"
    }
    foreach ($browser in @($Chrome, $MsEdge)) {
        if (Test-Path $browser) {
            Start-Process -FilePath $browser -ArgumentList $browserArgs
            return
        }
    }
    Start-Process $Url
}

# ============================================================
# 0. 校验部署目录
# ============================================================
if (-not (Test-Path (Join-Path $Repo 'package.json'))) {
    Show-Msg 'DSH 启动失败' "未找到 DSH 部署目录: $Repo`n`n请在 '$MachineCfg' 中设置 `$DSH_REPO 为 DSH 部署路径(含 package.json), 或重新运行 install.ps1。"
    exit 1
}

# ============================================================
# 1. 确保 DSH 服务运行
# ============================================================
if (-not (Test-PortListen)) {
    $nodeExe = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
    if (-not $nodeExe) {
        Show-Msg 'DSH 启动失败' "未找到 node.exe,无法启动 DSH 服务。"
        exit 1
    }
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outLog = Join-Path $LogDir "server-$stamp.out.log"
    $errLog = Join-Path $LogDir "server-$stamp.err.log"

    $env:DSH_HOME = $DshHome
    try {
        Start-Process -FilePath $nodeExe `
            -ArgumentList @('--import', 'tsx/esm', 'apps/cli/src/bin.ts', 'web') `
            -WorkingDirectory $Repo `
            -WindowStyle Hidden `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError  $errLog `
            | Out-Null
    } catch {
        Show-Msg 'DSH 启动失败' "无法启动服务进程:`n$_"
        exit 1
    }

    # 等待端口监听 (最多 120 秒)
    $deadline = (Get-Date).AddSeconds(120)
    do { Start-Sleep -Milliseconds 700 } until ((Test-PortListen) -or (Get-Date) -gt $deadline)
    if (-not (Test-PortListen)) {
        Show-Msg 'DSH 启动失败' "服务未能在 120 秒内监听端口 $Port 。`n日志目录: $LogDir"
        exit 1
    }
} else {
    # 端口被其他程序占用时给出提示
    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)" -ErrorAction SilentlyContinue
    if ($owner -and $owner.Name -ne 'node.exe') {
        Show-Msg 'DSH 提示' "端口 $Port 已被其他程序占用 ($($owner.Name) PID $($listener.OwningProcess)),将直接打开浏览器窗口,内容可能不是 DSH。"
    }
}

# ============================================================
# 2. 等待 Web 页面就绪
# ============================================================
$ready    = $false
$deadline = (Get-Date).AddSeconds(90)
do {
    Start-Sleep -Milliseconds 600
    try {
        $resp  = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
        $ready = ($resp.StatusCode -eq 200)
    } catch { $ready = $false }
} until ($ready -or (Get-Date) -gt $deadline)
if (-not $ready) {
    Show-Msg 'DSH 启动失败' "Web 页面未就绪 ($Url) 。`n请查看日志目录: $LogDir"
    exit 1
}

# ============================================================
# 3. 打开独立应用窗口
# ============================================================
Open-AppWindow
exit 0
