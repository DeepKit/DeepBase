#!/usr/bin/env bash
# A16 同进程多夹具真跑探针：一次进程挂入多件测试单元，核 found/pass 与 `Tests Leaked: 0`。
# 口径与 CodeReview/20260925-AUDIT-乙-B2-证据/b2_run_fixture.sh 完全一致（同一套 fail-closed），
# 差别只有 uses 从单单元改成多单元清单；产物全部落 .tmp，不是第二条构建路径。
#
# 用法: bash CodeReview/20261001-AUDIT-甲-A16-证据/附件/a16_run_multi_fixture.sh <tag> <Tests/x.pas> <Tests/y.pas> ... [-- DUnitX 参数]
set -u
export MSYS2_ARG_CONV_EXCL='*'
ROOT="$(git rev-parse --show-toplevel)"
BDS="${DEEPBASE_BDS:-D:/Program Files (x86)/Embarcadero/Studio/37.0}"
DCC="$BDS/bin/dcc64.exe"
DUNITX="${DEEPBASE_DUNITX_SOURCE:-D:/ProgramData/delphi/DUnitX/Source}"

if [ "$#" -lt 2 ]; then echo "用法见脚本头部注释"; exit 3; fi
TAG="$1"; shift
UNITS=()
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
  [ -f "$1" ] || { echo "测试单元不存在: $1"; exit 3; }
  UNITS+=("$(basename "$1" .pas)")   # 仓内约定：文件名即单元名
  shift
done
[ "${1:-}" = "--" ] && shift       # 余下参数原样透传给 DUnitX（如 --filter）
[ "${#UNITS[@]}" -ge 1 ] || { echo "至少一件测试单元"; exit 3; }

DIR="$ROOT/.tmp/a16/multi/$TAG"
rm -rf "$DIR" || { echo "无法清空探针目录（占用中？）: $DIR"; exit 3; }
mkdir -p "$DIR"

UNIT_LIST="$(IFS=,; echo "${UNITS[*]}")"
UNIT_LIST="${UNIT_LIST//,/, }"
sed "s/__UNITS__/$UNIT_LIST/" \
  "$ROOT/CodeReview/20261001-AUDIT-甲-A16-证据/附件/A16MultiFixtureRunner.dpr.template" > "$DIR/A16MultiFixtureRunner.dpr"

echo "== 同进程夹具清单: $UNIT_LIST =="
U="$ROOT/Core;$ROOT/Features;$ROOT/Persistence;$ROOT/VCL;$ROOT/FMX;$ROOT/Governance"
U="$U;$ROOT/Tests;$ROOT/Tests/Regression;$ROOT/Tests/Integration;$ROOT/DeepFlow/Source"
U="$U;$ROOT/DeepFlow/Source/Core;$ROOT/DeepFlow/Source/Workflow;$ROOT/doQry;$ROOT/ThirdParty"
U="$U;$BDS/lib/Win64/release;$DUNITX"
[ -n "${DEEPBASE_EXTRA_U:-}" ] && U="$U;$DEEPBASE_EXTRA_U"
NS="System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win"
[ -n "${DEEPBASE_EXTRA_NS:-}" ] && NS="$NS;$DEEPBASE_EXTRA_NS"
( cd "$ROOT" && "$DCC" -B "$DIR/A16MultiFixtureRunner.dpr" -NU"$DIR" -N0"$DIR" -E"$DIR" -U"$U" -NS"$NS" ) 2>&1
rc=$?
echo "BUILD_EXIT=$rc"
if [ "$rc" -ne 0 ]; then echo "== runner 编译未过 ⇒ 判据不成立 =="; exit 3; fi

echo
echo "== 真跑（同进程 $* ）=="
( cd "$DIR" && ./A16MultiFixtureRunner.exe "$@" ); rc=$?
echo "RUN_EXIT=$rc"
exit $rc
