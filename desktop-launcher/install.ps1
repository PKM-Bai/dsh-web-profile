# ============================================================
#  DSH 桌面版 - 安装脚本 (每台电脑运行一次)
#
#  用法 (PowerShell 或 CMD):
#    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
#    可选参数: -RepoPath "E:\GitProject\pkm-bai-deepseek-harness"
#
#  本脚本会:
#    1) 确定本机 DSH 部署目录, 写入 ~/.dsh/desktop-launcher/machine-config.ps1
#    2) 生成隐藏窗口包装脚本 launch-dsh.vbs / stop-dsh.vbs
#    3) 在桌面创建快捷方式: 「DSH 桌面版」「DSH 停止服务」
# ============================================================
param(
    [string]$RepoPath = ''
)
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

# ---------- 路径 ----------
$DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$InstDir = Join-Path $DshHome 'desktop-launcher'

# ---------- 1. 确定 DSH 部署目录 ----------
if (-not $RepoPath) { $RepoPath = $env:DSH_REPO }
if (-not $RepoPath) { $RepoPath = 'E:\GitProject\pkm-bai-deepseek-harness' }
if (-not (Test-Path (Join-Path $RepoPath 'package.json'))) {
    $RepoPath = Read-Host "未找到 DSH 部署目录(应包含 package.json 和 apps\cli\src\bin.ts)。`n请输入 DSH 部署目录的完整路径"
    if (-not (Test-Path (Join-Path $RepoPath 'package.json'))) {
        Write-Host "路径无效: $RepoPath" -ForegroundColor Red
        exit 1
    }
}
$RepoPath = [System.IO.Path]::GetFullPath($RepoPath)

# ---------- 2. 写入机器配置 ----------
New-Item -ItemType Directory -Force -Path $InstDir, (Join-Path $InstDir 'logs') | Out-Null
$cfg = "`$DSH_REPO = '$RepoPath'`r`n"
[System.IO.File]::WriteAllText((Join-Path $InstDir 'machine-config.ps1'), $cfg, (New-Object System.Text.UTF8Encoding $true))

# ---------- 3. 生成隐藏窗口包装脚本 ----------
$vbsLaunch = "Set sh = CreateObject(`"WScript.Shell`")`r`n" +
    "sh.Run `"powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"`"$ScriptDir\start-dsh.ps1`"`"`", 0, False`r`n"
$vbsStop   = "Set sh = CreateObject(`"WScript.Shell`")`r`n" +
    "sh.Run `"powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"`"$ScriptDir\stop-dsh.ps1`"`"`", 0, False`r`n"
[System.IO.File]::WriteAllText((Join-Path $InstDir 'launch-dsh.vbs'), $vbsLaunch, [System.Text.Encoding]::Default)
[System.IO.File]::WriteAllText((Join-Path $InstDir 'stop-dsh.vbs'),   $vbsStop,   [System.Text.Encoding]::Default)

# ---------- 4. 创建桌面快捷方式 ----------
$ws = New-Object -ComObject WScript.Shell
$desktop  = [Environment]::GetFolderPath('Desktop')
$wscript  = "$env:SystemRoot\System32\wscript.exe"
$icon     = Join-Path $ScriptDir 'dsh-app.ico'

$sc = $ws.CreateShortcut((Join-Path $desktop 'DSH 桌面版.lnk'))
$sc.TargetPath = $wscript
$sc.Arguments  = '"' + (Join-Path $InstDir 'launch-dsh.vbs') + '"'
$sc.WorkingDirectory = $InstDir
$sc.IconLocation = "$icon,0"
$sc.WindowStyle = 7
$sc.Description = '一键启动 DeepSeek Harness (DSH) 桌面版'
$sc.Save()

$sc2 = $ws.CreateShortcut((Join-Path $desktop 'DSH 停止服务.lnk'))
$sc2.TargetPath = $wscript
$sc2.Arguments  = '"' + (Join-Path $InstDir 'stop-dsh.vbs') + '"'
$sc2.WorkingDirectory = $InstDir
$sc2.IconLocation = "$icon,0"
$sc2.WindowStyle = 7
$sc2.Description = '停止 DSH 服务'
$sc2.Save()

# ---------- 5. 清理旧版脚本残留 (若曾装在 ~/.dsh/desktop-launcher) ----------
Remove-Item (Join-Path $InstDir 'start-dsh.ps1'), (Join-Path $InstDir 'stop-dsh.ps1') -Force -ErrorAction SilentlyContinue

# ---------- 完成 ----------
Write-Host ''
Write-Host '==============================================' -ForegroundColor Green
Write-Host '  DSH 桌面版安装完成!' -ForegroundColor Green
Write-Host "  DSH 部署目录 : $RepoPath"
Write-Host "  DSH_HOME     : $DshHome"
Write-Host "  快捷方式     : $desktop\DSH 桌面版.lnk"
Write-Host '==============================================' -ForegroundColor Green
Write-Host ''
Write-Host '提示: 若本机 DSH 部署目录与默认路径不同, 下次运行可带参数:'
Write-Host '  powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -RepoPath "你的部署路径"'
