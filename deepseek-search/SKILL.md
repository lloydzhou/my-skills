---
name: deepseek-search
description: 用 oapi 调用 DeepSeek Search/Fetch API——联网搜索（自研引擎，支持 site:/lang:/after: 等语法）与网页抓取（Markdown 正文）。当用户要求联网搜索、读取网页链接内容时使用。需已配置 DEEPSEEK_API_KEY 环境变量与 oapi ≥ 0.1.3。
---

# deepseek-search：DeepSeek Search/Fetch API

## 环境

- `command -v oapi` 通过，且版本 ≥ 0.1.4（connect 时存储凭据需要 0.1.4+；缺失或过旧提示用户升级：`cargo install --path <oapi仓库>` 或对应包管理器）
- `DEEPSEEK_API_KEY` 已设为环境变量（仅 connect 时用一次）
- 本 skill 已用 `oapi connect deepseek` 注册（见下）

## 密钥安全

- key 唯一合法形态：环境变量 + connect 时的 `-H 'Authorization: Bearer ${DEEPSEEK_API_KEY}'`（oapi 在 connect 时展开一次，存入 `~/.local/share/oapi/credentials/deepseek.json`，0600 仅本用户可读）
- 此后所有调用零 key、零环境变量：`oapi deepseek search ...` 自动附带存储的凭据
- key 不得出现在命令行明文、输出或对话上下文：禁止 `echo $DEEPSEEK_API_KEY`、禁止 `--header "Authorization: Bearer sk-xxx"`（真实 key 直接写死）
- 探测是否已配置只用布尔式：`[ -n "$DEEPSEEK_API_KEY" ] && echo 已设置`
- 凭据文件若被 chmod 成 group/other 可读，oapi **拒载并中止调用**（fail closed）；看到 `group/other-readable` 报错先 `chmod 600` 修复，不要改用明文传参
- 涉及 key 的环境变量配置（`~/.zshrc`）由用户本人手动维护，AI 不代为读写

## 注册（幂等；换 key 重跑同一命令即可）

```bash
oapi connect deepseek <skill目录>/deepseek-tools.openapi.json \
  -H 'Authorization: Bearer ${DEEPSEEK_API_KEY}'
```

- 重跑不带 `-H`：只刷新 spec，凭据保留
- 重跑带 `-H`：凭据替换（轮换 key 就这样做）
- `oapi sync deepseek`：刷新 spec，凭据保留
- `oapi rm deepseek`：spec 与凭据一起删除；`oapi ls` 里带凭据的 API 标 `+cred`

## 调用

body 字段一律用 `-F K=V`（自动类型推断，数字/布尔不需引号）；凭据由 oapi 自动附带，调用时不传任何 header：

```bash
# 搜索（默认 10 条；summary 600-800 字适合喂模型，content 需显式要）
oapi deepseek search -F query='DeepSeek V4 发布' --jq '.results'

# 搜索语法直接写在 query 里；用户原始问题可加 ori_question
oapi deepseek search -F query='rust async site:github.com lang:en after:2025' \
  -F count=5 -F need_content=true

# 抓单个网页，返回 Markdown 正文
oapi deepseek fetch -F url=https://example.com/article --jq '.content'
```

- `--jq` 过滤输出；`-o text` 输出纯文本
- 非 2xx 退出码为 1，错误信息在 stderr（含 HTTP 状态码与响应前 512 字节）
- 复杂嵌套参数才需要 `--body '<json>'`

## 结果字段速查

| 字段 | 含义 |
|---|---|
| `rerank_score` | 0–3，**≥1.5 为优质结果**，可用来筛选 |
| `summary` | 600–800 字长摘要，喂模型首选 |
| `snippet` | 100–200 字短摘要，前端展示用 |
| `content` | 网页正文；`need_content=false`（默认）时为空 |
| `authority` | 0–4，**≥3 为极权威**；`-1` 未知 |
| `date` | UTC RFC3339；未知为 null |

## 坑（官方文档实测要点）

| 坑 | 说明 |
|---|---|
| 计费 | Search/Fetch 各 **¥5/1000 次成功请求**；失败、无结果不计费。DSH/Claude Code/Codex 内置 server 端工具 2026-11-01 起也按次计费 |
| 限速 | 每账号各 5 QPS（Search/Fetch 独立）；Fetch 另有目标域名级限速 |
| 重试 | 408/429/5xx 等待后重试；**402 = 余额不足需充值**；其余 4xx 改请求后再试 |
| fetch 404 | 目标站不可用/被反爬/无 Markdown 正文，**不是参数错误**，换 URL 或改用 search |
| fetch URL | ≤8192 字符，必须 http/https 且含 host，**禁止用户名密码** |
| query 长度 | 1–128 Unicode 字符，搜索语法算在长度内 |
| content 取舍 | 全文优先用 fetch 按需抓；search 默认不返回正文可省 token（计费按次，与 count/need_content 无关） |

## 与 zai-skill 的关系

同仓的 zai-skill 走智谱 MCP（mcpc），本 skill 走 DeepSeek REST（oapi）。两者都提供搜索/读网页：按用户指定的服务商选择；未指定时 DeepSeek 渠道搜索质量更好，智谱渠道有 GitHub 仓库文档（zread）能力。
