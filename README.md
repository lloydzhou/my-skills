# my-skills

个人常用的 AI Agent Skills 集合（Claude Code / bash-agent 通用）。软链安装，`git pull` 即更新生效。

## Skills 索引

| Skill | 说明 | 依赖 |
|---|---|---|
| [zai-skill](zai-skill/) | 用 [mcpc](https://github.com/lloydzhou/mcpc) 调用智谱 Coding Plan MCP：联网搜索、读网页、GitHub 仓库文档 | `mcpc` + `ZHIPU_API_KEY` |
| [deepseek-search](deepseek-search/) | 用 [oapi](https://github.com/lloydzhou/oapi) 调用 DeepSeek Search/Fetch API：联网搜索、抓网页为 Markdown | `oapi` + `DEEPSEEK_API_KEY` |

## 安装

```bash
git clone git@github.com:lloydzhou/my-skills.git ~/my-skills
cd ~/my-skills && ./install.sh
```

`install.sh` 将每个含 `SKILL.md` 的子目录软链到 `~/.claude/skills/`，仓库内改动即时生效。

## 新增 skill

```
mkdir <skill名>/ && 写好 SKILL.md → 更新本 README 索引 → commit & push
```

## 约定

- 每个 skill 一个子目录，必须含 `SKILL.md`，可选附带配置样例/资源
- **密钥安全**：key 只进环境变量或配置占位符（如 `${ZHIPU_API_KEY}`），绝不出现在命令行、文档或仓库中
