#!/usr/bin/env bash
# session-triage を Claude Code のユーザースキルとして入れる。
#   ./scripts/install.sh          … コピーで入れる
#   ./scripts/install.sh --link   … このリポジトリへのシンボリックリンクで入れる（git pull で更新が反映される）
# 既にインストール済みなら、更新するかどうかのダイアログを出し、「はい」なら自動で入れ替える
# （古い版は ~/.claude/session-triage/backup/ に退避する）。ダイアログなしで更新するなら --yes。
# 既存の設定ファイル（~/.claude/session-triage/config.json）は上書きしない。
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_DIR/skills/session-triage"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DEST="$SKILLS_DIR/session-triage"
CONF_DIR="$HOME/.claude/session-triage"
CONF="$CONF_DIR/config.json"

mkdir -p "$SKILLS_DIR" "$CONF_DIR"

LINK=0; YES=0
for a in "$@"; do
  case "$a" in
    --link) LINK=1 ;;
    --yes|-y) YES=1 ;;
  esac
done

confirm_update() {
  [ "$YES" = 1 ] && return 0
  local msg="session-triage は既にインストールされています。最新版に更新しますか？
$DEST"
  if [ "$(uname)" = "Darwin" ] && command -v osascript >/dev/null 2>&1; then
    osascript -e 'on run argv
display dialog (item 1 of argv) with title "session-triage" buttons {"いいえ", "はい"} default button "はい"
end run' "$msg" 2>/dev/null | grep -q "はい" && return 0
    return 1
  elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v zenity >/dev/null 2>&1; then
    zenity --question --title=session-triage --text="$msg" && return 0
    return 1
  elif [ -t 0 ]; then
    read -r -p "$msg [y/N] " ans
    case "$ans" in [yY]*) return 0 ;; esac
    return 1
  fi
  echo "対話できないため更新しませんでした。--yes を付けると確認なしで更新します。" >&2
  return 1
}

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  if ! confirm_update; then
    echo "更新せずに終了しました。"
    exit 0
  fi
  if [ -L "$DEST" ]; then
    rm "$DEST"   # リンクだけ外す（中身のリポジトリは消えない）
  else
    BACKUP="$CONF_DIR/backup/session-triage-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$(dirname "$BACKUP")"
    mv "$DEST" "$BACKUP"
    echo "古い版を退避しました: $BACKUP"
  fi
  echo "更新します。"
fi

if [ "$LINK" = 1 ]; then
  ln -s "$SRC" "$DEST"
  echo "リンクしました: $DEST -> $SRC"
else
  cp -R "$SRC" "$DEST"
  echo "コピーしました: $DEST"
fi

if [ -e "$CONF" ] || [ -L "$CONF" ]; then
  echo "設定は既にあるので残しました: $CONF"
else
  cp "$SRC/config.example.json" "$CONF"
  echo "設定のひな形を置きました: $CONF（folder_rules などを自分用に直してください）"
fi

cat <<'EOF'

次の一歩:
  1. Claudeデスクトップアプリの Codeタブで「セッションを整理して」と頼む（1回だけ動かす）
  2. 定期実行にするなら「session-triage を15分おきに定期実行して」と頼む
     （examples/scheduled-task-prompt.md の文面をそのまま使えます）
EOF
