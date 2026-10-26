# session-triage を Claude Code のユーザースキルとして入れる（Windows / PowerShell 5.1 以降）。
#   .\scripts\install.ps1          … コピーで入れる
#   .\scripts\install.ps1 -Link    … このリポジトリへのジャンクションで入れる（git pull で更新が反映される。管理者権限は不要）
# 既にインストール済みなら、更新するかどうかのダイアログを出し、「はい」なら自動で入れ替える
# （古い版は %USERPROFILE%\.claude\session-triageackup\ に退避する）。ダイアログなしで更新するなら -Yes。
# 既存の設定ファイル（%USERPROFILE%\.claude\session-triage\config.json）は上書きしない。
# 実行ポリシーで止まるときは: powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
param(
  [switch]$Link,
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'

$RepoDir = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $RepoDir 'skills\session-triage'
$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$SkillsDir = if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $HomeDir '.claude\skills' }
$Dest = Join-Path $SkillsDir 'session-triage'
$ConfDir = Join-Path $HomeDir '.claude\session-triage'
$Conf = Join-Path $ConfDir 'config.json'

New-Item -ItemType Directory -Force -Path $SkillsDir, $ConfDir | Out-Null

function Confirm-Update {
  param([string]$Message)
  if ($Yes) { return $true }
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $r = [System.Windows.Forms.MessageBox]::Show($Message, 'session-triage', 'YesNo', 'Question')
    return ($r -eq 'Yes')
  } catch {
    $a = Read-Host "$Message [y/N]"
    return ($a -match '^[yY]')
  }
}

if (Test-Path -LiteralPath $Dest) {
  if (-not (Confirm-Update "session-triage は既にインストールされています。`n最新版に更新しますか？`n`n$Dest")) {
    Write-Host '更新せずに終了しました。'
    exit 0
  }
  $item = Get-Item -LiteralPath $Dest -Force
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    # ジャンクション/シンボリックリンクはリンクだけ外す（中身のリポジトリは消えない）
    $item.Delete()
  } else {
    $Backup = Join-Path $ConfDir ('backup\session-triage-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
    Move-Item -LiteralPath $Dest -Destination $Backup
    Write-Host "古い版を退避しました: $Backup"
  }
  Write-Host '更新します。'
}

if ($Link) {
  New-Item -ItemType Junction -Path $Dest -Target $Src | Out-Null
  Write-Host "リンクしました: $Dest -> $Src"
} else {
  Copy-Item -Recurse -LiteralPath $Src -Destination $Dest
  Write-Host "コピーしました: $Dest"
}

if (Test-Path -LiteralPath $Conf) {
  Write-Host "設定は既にあるので残しました: $Conf"
} else {
  Copy-Item -LiteralPath (Join-Path $Src 'config.example.json') -Destination $Conf
  Write-Host "設定のひな形を置きました: $Conf（folder_rules などを自分用に直してください）"
}

Write-Host @'

次の一歩:
  1. Claudeデスクトップアプリの Codeタブで「セッションを整理して」と頼む（1回だけ動かす）
  2. 定期実行にするなら「session-triage を15分おきに定期実行して」と頼む
     （examples\scheduled-task-prompt.md の文面をそのまま使えます）
'@
