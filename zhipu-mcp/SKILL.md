---
name: zhipu-mcp
description: 用 mcpc CLI 直接调用智谱 Coding Plan 的 MCP 服务——网络搜索(web_search_prime)、网页读取(webReader)、GitHub 仓库文档(zread: 目录结构/读文件/语义搜索)。当用户要求联网搜索、读取网页链接、查 GitHub 仓库用法/文件/结构时使用。需要 mcpc(@apify/mcpc) 和 ZHIPU_API_KEY。
---

# 智谱 MCP × mcpc

## 前置（key 的三层策略）

**优先级：环境变量 → mcpc 配置文件 → 均无则提示配置**

1. `ZHIPU_API_KEY` 环境变量（推荐在 `~/.zshrc` 中 export，一次配置全局生效）
2. mcpc 原生 secret 机制——配置文件支持 `${VAR}` 替换 + 会话记住认证：
   ```json
   // ~/.mcp.json  (mcpc 自动发现; 或任意路径用 "文件:条目" 引用)
   {
     "mcpServers": {
       "zs": { "url": "https://api.z.ai/api/mcp/web_search_prime/mcp",
               "headers": { "Authorization": "Bearer ${ZHIPU_API_KEY}" } },
       "zr": { "url": "https://api.z.ai/api/mcp/web_reader/mcp",
               "headers": { "Authorization": "Bearer ${ZHIPU_API_KEY}" } },
       "zd": { "url": "https://api.z.ai/api/mcp/zread/mcp",
               "headers": { "Authorization": "Bearer ${ZHIPU_API_KEY}" } }
     }
   }
   ```
3. 两者都没有 → 输出提示：`请设置 ZHIPU_API_KEY 环境变量后重试`

- api.z.ai 直连，**无需代理**（npm 安装 mcpc 时才需要）
- `command -v mcpc >/dev/null || echo "未安装 mcpc,请先执行: npm i -g @apify/mcpc"`

## 1. 建会话（幂等；断线后重跑自愈；认证只在此时发生）

```bash
# 方式A: 从配置文件建(推荐——key 由 mcpc 进程从环境变量替换,命令行不出现key)
mcpc connect ~/.mcp.json:zs @zs --protocol-version 2024-11-05
mcpc connect ~/.mcp.json:zr @zr --protocol-version 2024-11-05
mcpc connect ~/.mcp.json:zd @zd --protocol-version 2024-11-05

# 方式B: 一键连配置里全部 server(自动发现 ~/.mcp.json 等)
mcpc connect
```

会话建立后（状态存 `~/.mcpc/sessions.json`），后续 `tools-call` **不再需要 key**。

## 🔒 密钥安全规则（必须遵守）

**key 绝不允许出现在命令行参数、echo 输出、tool_result 或对话上下文中。**

- key 唯一合法形态：环境变量 `ZHIPU_API_KEY` + `~/.mcp.json` 里的 `${ZHIPU_API_KEY}` **占位符**（由 mcpc 进程内部替换）
- **禁止**：`echo $ZHIPU_API_KEY`、`-H "Authorization: Bearer $ZHIPU_API_KEY"`（拼进命令行）、`grep key ~/.zshrc`、`cat` 任何含 key 的文件
- 检查 key 是否已配置只用布尔探测（不输出值）：
  ```bash
  [ -n "$ZHIPU_API_KEY" ] && echo "ZHIPU_API_KEY: 已设置" || echo "ZHIPU_API_KEY: 未设置"
  ```
- connect/调用失败需要排查时，看 mcpc 日志（`~/.mcpc/logs/`）的**错误码**而非回显 header

## 2. 调用（三个会话、六个常用工具）

```bash
# 搜索（@zs）——recency 可选: oneDay/oneWeek/oneMonth/oneYear
mcpc @zs tools-call web_search_prime search_query:="关键词" search_recency_filter:=oneWeek

# 读网页（@zr）
mcpc @zr tools-call webReader url:=https://example.com

# GitHub 仓库（@zd）
mcpc @zd tools-call get_repo_structure repo_name:=facebook/react
mcpc @zd tools-call read_file repo_name:=facebook/react file_path:=README.md
mcpc @zd tools-call search_doc repo_name:=facebook/react query:="hooks cleanup" language:=zh
```

参数形态两种皆可：`k:=v` 展开式，或整体传 JSON 字符串（如 `'{"k":"v"}'`）。未知工具先 `tools-list --full` 或 `tools-get <name>` 查 schema。

## 3. 输出解析

默认人读格式（正文在代码块内）。程序化处理用 `--json`：
**注意 `content[0].text` 是"字符串化的 JSON"，需二次 `json.loads`** 才得到对象/数组：

```bash
mcpc --json @zs tools-call web_search_prime search_query:=test | \
  python3 -c 'import json,sys;print(json.loads(json.load(sys.stdin)["content"][0]["text"]))'
```

## 会话管理

```bash
mcpc                 # 列出全部会话及 ● live 状态
mcpc close @zs       # 关闭单个
```

## 坑（实测验证）

| 坑 | 说明 |
|---|---|
| URL 两段 `/mcp` | `api.z.ai/api/mcp/<能力>/mcp`，少一段返回 404 |
| 协议版本 | 必须 `--protocol-version 2024-11-05`，不钉则协商失败 |
| zread 索引 | 小众仓库可能 `repo not found`（服务端限制，换 read_file 也不行就是没收录） |
| 非 MCP 能力 | vision/file_parser 走 legacy API，本 skill 不覆盖，用 zhipu-tools-coding-plan |
