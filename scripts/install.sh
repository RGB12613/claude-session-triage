#!/usr/bin/env bash
# session-triage を Claude Code のユーザースキルとして入れる。
#   ./scripts/install.sh          … コピーで入れる
#   ./scripts/install.sh --link   … このリポジトリへのシンボリックリンクで入れる（git pull で更新が反映される）
# 既存の設定ファイル（~/.claude/session-triage/config.json）は上書きしない。
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_DIR/skills/session-triage"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DEST="$SKILLS_DIR/session-triage"
CONF_DIR="$HOME/.claude/session-triage"
CONF="$CONF_DIR/config.json"

mkdir -p "$SKILLS_DIR" "$CONF_DIR"

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  echo "既に $DEST があります。中身を確かめて、不要なら手で退避してから再実行してください。" >&2
  exit 1
fi

if [ "${1:-}" = "--link" ]; then
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
