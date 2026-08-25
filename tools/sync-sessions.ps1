# ============================================================
#  DSH 会话同步脚本 (Session Sync) — git 方案
#
#  私有仓库缓冲 DSH 的会话/存储/任务台账/附件, 在 家用/公司 两台电脑间同步。
#  缓冲仓库默认 E:\DSH-Sessions (不要放 C 盘, 避免占用系统盘空间)。
#
#  用法:
#    powershell -NoProfile -ExecutionPolicy Bypass -File sync-sessions.ps1 -Push
#    powershell -NoProfile -ExecutionPolicy Bypass -File sync-sessions.ps1 -Pull
#
#  参数:
#    -RepoPath  会话缓冲仓库路径 (默认 E:\DSH-Sessions, 可用 -RepoPath 覆盖)
#    -Force     跳过"DSH 服务正在运行"等确认提示
#    -NoPush    推送模式下仅提交到本地缓冲, 不推送到远端
#
#  使用约定: 同一时间只在一台电脑上运行 DSH; 换机前 -Push, 换机后 -Pull。
# ============================================================
param(
    [switch]$Push,      # 推送模式: 本机数据 -> 仓库
    [switch]$Pull,      # 拉取模式: 仓库 -> 本机
    [string]$RepoPath = 'E:\DSH-Sessions',
    [switch]$Force,     # 跳过"服务正在运行"等确认提示
    [switch]$NoPush     # 推送模式下仅提交到本地缓冲, 不推送远端
)
if ($Push -and $Pull) { throw '不能同时指定 -Push 和 -Pull' }
$Mode = if ($Pull) { 'pull' } else { 'push' }
# 注意: 保持 Continue —— git 等外部命令的 stderr 经 2>&1 汇入输出流,
# 若用 Stop 会把 git 的普通 stderr 输出当成终止错误; 错误已用 $LASTEXITCODE 显式检查。
$ErrorActionPreference = 'Continue'
$Port = 3080

$DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$Repo    = [System.IO.Path]::GetFullPath($RepoPath)
# 需要同步的 DSH 数据目录 (attachments 可能尚不存在, 会自动跳过)
$Dirs    = @('sessions', 'storages', 'task-board', 'attachments')

# ---------- 工具函数 ----------
function Test-ServerRunning {
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Confirm-OrAbort([string]$Msg) {
    if ($Force) { return }
    $ans = Read-Host "$Msg`n输入 y 继续, 其他任意键取消"
    if ($ans -ne 'y' -and $ans -ne 'Y') { Write-Host '已取消。' -ForegroundColor Yellow; exit 0 }
}

function Get-Branch {
    $b = git -C $Repo branch --show-current
    if (-not $b) { $b = ((git -C $Repo symbolic-ref --short refs/remotes/origin/HEAD) -replace '^origin/', '') }
    return $b
}

function Sync-Mirror([string]$src, [string]$dst) {
    if (-not (Test-Path $src)) { Write-Host "跳过 (本机不存在): $src"; return }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy 失败: $src -> $dst (exit $LASTEXITCODE)" }
    Write-Host "已镜像: $src"
}

# ---------- 前置检查 ----------
if (Test-ServerRunning) {
    Write-Host "警告: DSH 服务正在运行 (端口 $Port), 会话文件可能正在写入。" -ForegroundColor Yellow
    Confirm-OrAbort '强烈建议先停止 DSH 服务 (桌面「DSH 停止服务」) 再同步。'
}
if (-not (Test-Path (Join-Path $Repo '.git'))) {
    Write-Host "错误: 未找到同步仓库 $Repo (缺少 .git)。" -ForegroundColor Red
    Write-Host '请先克隆私有仓库, 例如:' -ForegroundColor Yellow
    Write-Host '  git clone https://ghproxy.net/https://github.com/PKM-Bai/dsh-sessions.git E:\DSH-Sessions' -ForegroundColor Yellow
    exit 1
}
$branch = Get-Branch
if (-not $branch) { Write-Host '错误: 无法确定仓库分支。'; exit 1 }

# 缓冲仓库先与远端对齐 (缓冲只是镜像, 丢弃本地差异是安全的, 避免两机合并冲突)
git -C $Repo fetch origin 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host '警告: git fetch 失败 (可能无远端或网络问题), 继续使用本地缓冲。' -ForegroundColor Yellow
}
$originRef = "origin/$branch"
git -C $Repo rev-parse --verify --quiet $originRef *> $null
if ($LASTEXITCODE -eq 0) {
    git -C $Repo reset --hard $originRef 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'git reset --hard 失败' }
    Write-Host "缓冲仓库已对齐到远端 $originRef"
} else {
    Write-Host '远端分支尚不存在 (首次推送前), 使用空缓冲。'
}

# ---------- 执行 ----------
if ($Mode -eq 'push') {
    # 本机 DSH 数据 -> 缓冲仓库 -> 提交 -> 推送
    foreach ($d in $Dirs) { Sync-Mirror (Join-Path $DshHome $d) (Join-Path $Repo $d) }

    git -C $Repo add -A 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'git add 失败' }
    $staged = git -C $Repo status --porcelain
    if (-not $staged) {
        Write-Host '没有变化, 无需提交。' -ForegroundColor Green
    } else {
        $msg = "sync: DSH sessions snapshot $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git -C $Repo commit -m $msg 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git commit 失败' }
        Write-Host "已提交: $msg" -ForegroundColor Green
        if (-not $NoPush) {
            git -C $Repo push origin $branch 2>&1
            if ($LASTEXITCODE -ne 0) { throw 'git push 失败' }
            Write-Host '已推送到远端。' -ForegroundColor Green
        } else {
            Write-Host '(-NoPush) 仅提交到本地缓冲, 未推送。' -ForegroundColor Yellow
        }
    }
} else {
    # 缓冲仓库 (已对齐远端) -> 本机 DSH 数据
    Write-Host '警告: 拉取会用仓库内容覆盖本机会话目录。' -ForegroundColor Yellow
    Confirm-OrAbort '本机未推送的会话将被覆盖。'
    foreach ($d in $Dirs) {
        $src = Join-Path $Repo $d
        if (Test-Path $src) { Sync-Mirror $src (Join-Path $DshHome $d) }
    }
    Write-Host '本机会话已更新为仓库版本。' -ForegroundColor Green
}

Write-Host "完成 (缓冲仓库: $Repo)" -ForegroundColor Green
