#!/bin/bash
# 编译 .tmp/b13 下的时间语义探针（dcc64 开关值必须与开关紧邻，不能空格分隔）
set -u
export MSYS2_ARG_CONV_EXCL='*'
BDS="D:/Program Files (x86)/Embarcadero/Studio/37.0"
SRC="$1"; NAME="$(basename "$SRC" .dpr)"
"$BDS/bin/dcc64.exe" -Q -NU".tmp/b13/out" -E".tmp/b13/out" \
  -O"$BDS/lib;$BDS/lib/Win64;$BDS/lib/Win64/release" \
  -U"$BDS/lib;$BDS/lib/Win64;$BDS/lib/Win64/release" \
  -I"$BDS/lib;$BDS/lib/Win64" "$SRC"
echo "BUILD_EXIT=$?"
".tmp/b13/out/$NAME.exe" > ".tmp/b13/${NAME}_raw.txt" 2>&1
echo "RUN_EXIT=$?"
