#!/bin/bash
# 将本仓库所有 skill 安装到 ~/.agents/skills/（主安装位），
# 并在 ~/.claude/skills/ 做符号链接指向它（幂等, 可重复执行）。
set -euo pipefail
cd "$(dirname "$0")"
AGENTS_DEST="${HOME}/.agents/skills"
CLAUDE_DEST="${HOME}/.claude/skills"
mkdir -p "$AGENTS_DEST" "$CLAUDE_DEST"

installed=0
for d in */; do
  name="${d%/}"
  [ -f "$d/SKILL.md" ] || continue
  src="$(pwd)/$name"

  # 主安装位: ~/.agents/skills/<name> → 仓库目录
  if [ -e "$AGENTS_DEST/$name" ] && [ ! -L "$AGENTS_DEST/$name" ]; then
    echo "⚠ $AGENTS_DEST/$name 已存在且不是符号链接, 跳过 (请手动处理)"
    continue
  fi
  ln -sfn "$src" "$AGENTS_DEST/$name"

  # Claude Code: ~/.claude/skills/<name> → ~/.agents/skills/<name>
  if [ -e "$CLAUDE_DEST/$name" ] && [ ! -L "$CLAUDE_DEST/$name" ]; then
    echo "⚠ $CLAUDE_DEST/$name 已存在且不是符号链接, 跳过 (请手动处理)"
    continue
  fi
  ln -sfn "$AGENTS_DEST/$name" "$CLAUDE_DEST/$name"
  echo "✓ $name → $AGENTS_DEST/$name → 仓库"
  installed=$((installed+1))
done

[ $installed -gt 0 ] && echo -e "\n完成: $installed 个 skill 已链接, git pull 后自动生效" \
                    || echo "未发现任何含 SKILL.md 的子目录"
