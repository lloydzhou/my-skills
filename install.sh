#!/bin/bash
# 将本仓库所有 skill 软链到 ~/.claude/skills/ (幂等, 可重复执行)
set -euo pipefail
cd "$(dirname "$0")"
DEST="${HOME}/.claude/skills"
mkdir -p "$DEST"

installed=0
for d in */; do
  name="${d%/}"
  [ -f "$d/SKILL.md" ] || continue
  ln -sfn "$(pwd)/$name" "$DEST/$name"
  echo "✓ $name → $DEST/$name"
  installed=$((installed+1))
done

[ $installed -gt 0 ] && echo -e "\n完成: $installed 个 skill 已链接, git pull 后自动生效" \
                    || echo "未发现任何含 SKILL.md 的子目录"
