#!/bin/bash
# DeepSeek OCR/ASR/TTS 三接口连通性自检（官方文档口径，实测请以此为准）。
# 前提：oapi ≥ 0.1.5、已 `oapi connect deepseek ... -H ...` 注册凭据、余额充足。
# 消耗：OCR 1 页 ≈ ¥0.0015、ASR 约 2 秒音频、TTS 13 字 ≈ ¥0.004（限时 5 折后）。
set -euo pipefail
cd "$(dirname "$0")"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "== 准备测试文件 =="
# ASR 音频：macOS say 生成中文语音，afconvert 转 16bit PCM WAV
say -o "$TMP/speech.aiff" "你好，今天天气怎么样"
afconvert -f WAVE -d LEI16@16000 -c 1 "$TMP/speech.aiff" "$TMP/speech.wav"
echo "asr 音频: $(ls -l "$TMP/speech.wav" | awk '{print $5}') bytes"

# OCR 文档：python 生成单页 PDF（无第三方依赖，xref 偏移自动计算）
python3 - "$TMP/doc.pdf" <<'PY'
import sys
objs = []
objs.append(b"<< /Type /Catalog /Pages 2 0 R >>")
objs.append(b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
objs.append(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>")
stream = b"BT /F1 24 Tf 72 720 Td (DeepSeek OCR test 123) Tj ET"
objs.append(b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream")
out = b"%PDF-1.4\n"
offsets = []
for i, o in enumerate(objs, 1):
    offsets.append(len(out))
    out += str(i).encode() + b" 0 obj\n" + o + b"\nendobj\n"
xref = len(out)
out += b"xref\n0 " + str(len(objs) + 1).encode() + b"\n0000000000 65535 f \n"
for off in offsets:
    out += ("%010d 00000 n \n" % off).encode()
out += b"trailer\n<< /Size " + str(len(objs) + 1).encode() + b" /Root 1 0 R >>\n%%EOF\n"
open(sys.argv[1], "wb").write(out)
PY
echo "ocr 文档: $(ls -l "$TMP/doc.pdf" | awk '{print $5}') bytes"

echo "== ASR =="
oapi deepseek asr -F file=@"$TMP/speech.wav"

echo "== OCR =="
oapi deepseek ocr -F purpose=text_recognition -F file=@"$TMP/doc.pdf" --jq '.page_count, .pages[0].text'

echo "== TTS =="
oapi deepseek tts --body '{"text":"你好，我是 DeepSeek。","voice_id":"stella"}' -o "$TMP/tts.wav"
afinfo "$TMP/tts.wav" 2>/dev/null | grep -E "duration|data format" || ls -l "$TMP/tts.wav"

echo "== 全部通过 =="
