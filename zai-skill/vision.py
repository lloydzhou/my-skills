#!/usr/bin/env python3
"""vision —— 用智谱 glm-4.6v 识图 (key 从环境变量 ZHIPU_API_KEY 读取, 永不回显)"""
import base64, json, os, sys, urllib.request

img_path = sys.argv[1] if len(sys.argv) > 1 else "/Users/lloyd/Downloads/wallpaper_2.jpg"
prompt = sys.argv[2] if len(sys.argv) > 2 else "详细描述这张图片的内容、风格、色调和值得注意的细节"

key = os.environ.get("ZHIPU_API_KEY", "")
if not key:
    sys.exit("ZHIPU_API_KEY 未设置(布尔探测失败)")

if img_path.startswith(("http://", "https://")):
    image_url_value = img_path          # 远程 URL 直传
else:
    with open(img_path, "rb") as f:     # 本地文件 base64
        image_url_value = "data:image/jpeg;base64," + base64.b64encode(f.read()).decode()

body = json.dumps({
    "model": "glm-4.6v",
    "messages": [{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": image_url_value}},
            {"type": "text", "text": prompt},
        ],
    }],
}).encode()

req = urllib.request.Request(
    "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions",
    data=body,
    headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
)
try:
    resp = urllib.request.urlopen(req, timeout=120)
    d = json.loads(resp.read())
    print(d["choices"][0]["message"]["content"])
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()[:200]}")
