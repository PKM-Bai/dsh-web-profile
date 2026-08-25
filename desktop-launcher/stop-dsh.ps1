# ============================================================
#  DSH 服务停止助手 (便携版)
#  停止监听 3080 端口的 DSH 服务进程 (浏览器窗口需手动关闭)
# ============================================================
$ErrorActionPreference = 'Stop'
$Port = 3080

function Show-Msg([string]$Title, [string]$Text) {
    $ws = New-Object -ComObject WScript.Shell
    [void]$ws.Popup($Text, 0, $Title, 64 + 4096)   # 64=信息图标, 4096=系统置顶
}

$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $listener) {
    Show-Msg 'DSH 服务' "DSH 服务当前未运行 (端口 $Port)。"
    exit 0
}

$owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)" -ErrorAction SilentlyContinue
$name  = if ($owner) { $owner.Name } else { "PID $($listener.OwningProcess)" }

Stop-Process -Id $listener.OwningProcess -Force -ErrorAction SilentlyContinue
Show-Msg 'DSH 服务' "已停止 DSH 服务 ($name, PID $($listener.OwningProcess))。`n浏览器窗口可手动关闭。"
exit 0
