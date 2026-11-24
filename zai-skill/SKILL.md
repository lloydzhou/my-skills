---
name: zai-skill
description: 调用智谱 Coding Plan 的 MCP 服务——联网搜索(web_search_prime)、网页读取(webReader)、GitHub 仓库文档(zread: 结构/读文件/语义搜索)、图像理解(vision.py/glm-4.6v)。当用户要求联网搜索、读取网页链接、查 GitHub 仓库用法、识图/看图时使用。需已配置 ZHIPU_API_KEY 环境变量。
---

# zai-skill：智谱 MCP 工具

## 环境

- `command -v mcpc` 通过（缺失则提示用户安装：`brew install lloydzhou/tap/mcpc`，Linux 用 AUR `mcpc`）
- `ZHIPU_API_KEY` 已设为环境变量（api.z.ai 直连，无需代理）

## 密钥安全

- key 唯一合法形态：环境变量 + connect 时的 `-H "Authorization: Bearer $ZHIPU_API_KEY"`（双引号让 shell 展开）
- key 只在 connect 时经过一次命令行，随后由 mcpc 存入 `~/.local/share/mcpc/credentials/<会话名>.json`（0600，仅本用户可读）；缓存文件只留 `<stored>` 引用，不含明文
- 此后调用、daemon 重启均零 key：会话由 daemon 持有，启动时自动恢复
- key 不得出现在输出或对话上下文：禁止 `echo $ZHIPU_API_KEY`、禁止把真实 key 写进任何文件
- 探测是否已配置只用布尔式：`[ -n "$ZHIPU_API_KEY" ] && echo 已设置`
- 涉及 key 的环境变量配置（`~/.zshrc`）由用户本人手动维护，AI 不代为读写

## 建会话（首次 connect；换 key 或断线后重连）

```bash
mcpc connect https://api.z.ai/api/mcp/web_search_prime/mcp @zs -H "Authorization: Bearer $ZHIPU_API_KEY" --protocol-version 2024-11-05
mcpc connect https://api.z.ai/api/mcp/web_reader/mcp @zr -H "Authorization: Bearer $ZHIPU_API_KEY" --protocol-version 2024-11-05
mcpc connect https://api.z.ai/api/mcp/zread/mcp @zd -H "Authorization: Bearer $ZHIPU_API_KEY" --protocol-version 2024-11-05
```

- 会话 live 时重跑 connect 报 `already live`；断线后 daemon 自动清理 dead session，直接重跑即可
- 换 key / 轮换：`mcpc close @NAME`（删除会话及其存储的凭据）后用新 key 重新 connect
- daemon 无需手动管理：普通命令首次执行自动拉起；会话在 daemon 重启后凭存储的凭据自动恢复
- `mcpc ls` 看各会话 live 状态；`mcpc daemon status` 显式探测 daemon（停止时退出码 3，不会拉起）

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
| 重复 connect | 会话 live 时报 `session '@xx' already live`；换 key 先 `close @xx` 再 connect |
| 调用方式 | 裸命令直调。勿用 `zsh -ic` 等交互壳包装（与 mcpc daemon 冲突，异常退出） |
| zread 覆盖 | 小众仓库可能 `repo not found`（服务端索引限制，非调用问题） |
| vision 无 MCP 端点 | 已实测确认，只能走下方直连 API |

## vision（图像理解，MCP 之外的唯一例外）

glm-4.6v 只有 Chat Completions 形态，无 MCP 端点，用附属脚本直连（Coding Plan 免费通道）：

```bash
python3 <skill目录>/vision.py <图片路径|URL> ["提示词(默认:详细描述图片)"]
```

- key 从环境变量 `ZHIPU_API_KEY` 读取（脚本内部，不回显）；本地图片自动 base64，URL 直传
- 直接用 Bash 执行即可，无需任何环境注入包装
