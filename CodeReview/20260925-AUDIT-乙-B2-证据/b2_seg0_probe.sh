#!/usr/bin/env bash
# B2 段0 取证探针一键复算（一次性，不进任何构建面）
# 目的：用实测回答两个「不采信转述」的问题——
#   P1 TJSONObject 里 TJSONBool 值能否被 TryGetValue<string> 取回（B2-01 字面结论）
#   P2 TCriticalSection 同线程二次 Enter 是否阻塞（B2-11 锁语义前提）
# 探针源件落在仓库 .tmp/b2/（已被 .gitignore 排除），本脚本只负责复现「编译 + 运行 + 原始输出」。
set -u
ROOT="$(git rev-parse --show-toplevel)"
BDS="/d/Program Files (x86)/Embarcadero/Studio/37.0"
DCC="$BDS/bin/dcc64.exe"
SRC="$ROOT/.tmp/b2"
OUT="$SRC/out"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
# 探针源件在册落在本证据目录的 附件/ 下，复算时复制进 .tmp 再编（证据不依赖 gitignored 目录）。
cp "$HERE/附件/B2Seg0Probe.dpr" "$SRC/"

echo "== 编译器版本 =="
"$DCC" -b 2>&1 | head -2
echo "EXIT=$?"

echo
echo "== 编译 $SRC/B2Seg0Probe.dpr =="
( cd "$SRC" && "$DCC" -B -E"$OUT" -N0"$OUT" \
    -U"$BDS/lib/Win64/release" -I"$BDS/Include" \
    -NS"System;Winapi" B2Seg0Probe.dpr ) 2>&1
echo "BUILD_EXIT=${PIPESTATUS[0]}"

echo
echo "== 运行 =="
"$OUT/B2Seg0Probe.exe"
echo "RUN_EXIT=$?"
