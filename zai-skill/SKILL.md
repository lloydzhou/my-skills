---
name: zai-skill
description: 调用智谱 Coding Plan 的 MCP 服务——联网搜索(web_search_prime)、网页读取(webReader)、GitHub 仓库文档(zread: 结构/读文件/语义搜索)、图像理解(vision.py/glm-4.6v)。当用户要求联网搜索、读取网页链接、查 GitHub 仓库用法、识图/看图时使用。需已配置 ZHIPU_API_KEY 环境变量。
---

# zai-skill：智谱 MCP 工具

## 环境

- `command -v mcpc` 通过（缺失则提示用户：`npm i -g @apify/mcpc`）
- `ZHIPU_API_KEY` 已设为环境变量（api.z.ai 直连，无需代理）
- `~/.mcp.json` 含下方三个 server 条目

```json
// ~/.mcp.json —— 若已存在,将条目合并进 mcpServers,切勿整文件覆盖
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

## 密钥安全

- key 唯一合法形态：环境变量 + 上述配置中的 `${ZHIPU_API_KEY}` 占位符，由 mcpc 进程内部替换
- key 不得出现在命令行参数、输出或对话上下文中：禁止 `echo $ZHIPU_API_KEY`、禁止拼 `-H "Authorization: Bearer $ZHIPU_API_KEY"`
- 探测是否已配置只用布尔式：`[ -n "$ZHIPU_API_KEY" ] && echo 已设置`
- 涉及 key 的配置（`~/.zshrc`、`~/.mcp.json`）由用户本人手动维护，AI 不代为读写

## 建会话（幂等，断线重跑自愈）

```bash
mcpc connect ~/.mcp.json:zs @zs --protocol-version 2024-11-05
mcpc connect ~/.mcp.json:zr @zr --protocol-version 2024-11-05
mcpc connect ~/.mcp.json:zd @zd --protocol-version 2024-11-05
```

会话认证全局持久（`~/.mcpc/`），此后 `tools-call` 阶段零 key。`mcpc`（无参数）可查看各会话 `● live` 状态。

## 调用（3 会话 / 6 工具）

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

参数支持 `k:=v` 展开式或整体 JSON（`'{"k":"v"}'`）。未知工具先 `tools-list --full` 查 schema。

## 输出解析

加 `--json` 程序化处理。注意 `content[0].text` 是**多层字符串化的 JSON（层级不稳定，实测 2~3 层），需循环解析**：

```bash
mcpc --json @zs tools-call web_search_prime search_query:=test > /tmp/zai_out.json
python3 -c '
import json
t = json.load(open("/tmp/zai_out.json"))["content"][0]["text"]
for _ in range(4):
    if isinstance(t,str):
        try: t = json.loads(t)
        except Exception: break
    else: break
print(t)'
```

（建议先落盘再解析；长输出直接管道偶发静默丢失。）

## 坑（实测）

| 坑 | 说明 |
|---|---|
| 端点拼写 | `api.z.ai/api/mcp/<能力>/mcp` 两段 `/mcp`，少一段 404 |
| 协议版本 | connect 必须 `--protocol-version 2024-11-05`，否则协商失败 |
| 调用方式 | 裸命令直调。勿用 `zsh -ic` 等交互壳包装（与 mcpc daemon 冲突，异常退出） |
| zread 覆盖 | 小众仓库可能 `repo not found`（服务端索引限制，非调用问题） |
| domain 过滤无效 | `search_domain_filter` 实测不生效（返回结果不按域名过滤），需要域名限定时改在 `search_query` 里手写 `site:github.com` |
| vision URL 源 | 图片 URL 须可被智谱服务端公网抓取；有反爬的源（如 wikimedia）返回 400"格式/解析错误"，此时下载到本地走 base64 |
| vision 无 MCP 端点 | 已实测确认，只能走下方直连 API |

## vision（图像理解，MCP 之外的唯一例外）

glm-4.6v 只有 Chat Completions 形态，无 MCP 端点，用附属脚本直连（Coding Plan 免费通道）：

```bash
python3 <skill目录>/vision.py <图片路径|URL> ["提示词(默认:详细描述图片)"]
```

- key 从环境变量 `ZHIPU_API_KEY` 读取（脚本内部，不回显）；本地图片自动 base64，URL 直传
- 直接用 Bash 执行即可，无需任何环境注入包装
