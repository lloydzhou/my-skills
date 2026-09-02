# zhipu-mcp-skill

一个极简的 Claude Code / bash-agent Skill：通过 [mcpc](https://github.com/apify/mcpc)（通用 MCP CLI client）调用智谱 Coding Plan 的 MCP 服务。

**设计哲学：skill 是知识不是代码** —— 不封装任何脚本，只提供智谱特有的端点/协议/坑位知识，命令全部是可原样执行的 mcpc 原生命令。

## 提供的能力

| 会话 | 工具 | 用途 |
|---|---|---|
| `@zs` | `web_search_prime` | 联网搜索（支持时效过滤） |
| `@zr` | `webReader` | 读取网页正文 |
| `@zd` | `get_repo_structure` / `read_file` / `search_doc` | GitHub 仓库结构 / 读文件 / 语义搜索 |

## 安装

```bash
npm i -g @apify/mcpc                      # MCP CLI 底座
mkdir -p ~/.claude/skills/zhipu-mcp
cp SKILL.md ~/.claude/skills/zhipu-mcp/
cp mcp.json ~/.mcp.json                   # mcpc 自动发现配置(Claude Desktop/VS Code 兼容)
echo 'export ZHIPU_API_KEY="你的key"' >> ~/.zshrc   # key 只进环境变量
```

## 密钥安全

key 唯一合法形态：环境变量 + `mcp.json` 里的 `${ZHIPU_API_KEY}` 占位符（mcpc 进程内部替换）。
**绝不**出现在命令行参数、echo 输出、tool_result 或 LLM 对话上下文中。详见 SKILL.md 的安全规则小节。

## 实测坑位（都已写进 SKILL.md）

- 端点拼写：`api.z.ai/api/mcp/<能力>/mcp`（两段 /mcp，少一段 404）
- 必须 `--protocol-version 2024-11-05`
- zread 对小众仓库可能 `repo not found`（服务端索引限制）
- api.z.ai 直连无需代理
