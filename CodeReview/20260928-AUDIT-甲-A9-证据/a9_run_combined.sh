#!/usr/bin/env bash
# A9 合并真跑探针：把 附件/A9CombinedRunner.dpr.template 实体化到 gitignored 的 .tmp 后编译运行。
#
# 为什么另立一支而不复用 b2_run_fixture.sh：后者按「单单元」模板替换 __UNIT__，
# 本单需要的是「9 件同时挂载」的相互干扰面（工单 §一 判据只要求逐件，合并面是甲自加的零回归对照）。
# 搜索面/命名空间/三道 fail-closed 与 b2_run_fixture.sh 同一口径，不另立一套判据。
#
# 用法: bash CodeReview/20260928-AUDIT-甲-A9-证据/a9_run_combined.sh [DUnitX 参数]
set -u
export MSYS2_ARG_CONV_EXCL='*'
ROOT="$(git rev-parse --show-toplevel)"
BDS="${DEEPBASE_BDS:-D:/Program Files (x86)/Embarcadero/Studio/37.0}"
DCC="$BDS/bin/dcc64.exe"
DUNITX="${DEEPBASE_DUNITX_SOURCE:-D:/ProgramData/delphi/DUnitX/Source}"
DIR="$ROOT/.tmp/a9/combined"
rm -rf "$DIR" || { echo "无法清空探针目录（占用中？）: $DIR"; exit 3; }
mkdir -p "$DIR"
cp "$ROOT/CodeReview/20260928-AUDIT-甲-A9-证据/附件/A9CombinedRunner.dpr.template" "$DIR/A9CombinedRunner.dpr"

echo "== 编译合并 runner（ROOT=$ROOT） =="
U="$ROOT/Core;$ROOT/Features;$ROOT/Persistence;$ROOT/VCL;$ROOT/FMX;$ROOT/Governance"
U="$U;$ROOT/Tests;$ROOT/Tests/Regression;$ROOT/Tests/Integration;$ROOT/DeepFlow/Source"
U="$U;$ROOT/DeepFlow/Source/Core;$ROOT/DeepFlow/Source/Workflow;$ROOT/doQry;$ROOT/ThirdParty"
U="$U;$BDS/lib/Win64/release;$DUNITX"
[ -n "${DEEPBASE_EXTRA_U:-}" ] && U="$U;$DEEPBASE_EXTRA_U"
NS="System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win"
[ -n "${DEEPBASE_EXTRA_NS:-}" ] && NS="$NS;$DEEPBASE_EXTRA_NS"
( cd "$ROOT" && "$DCC" -B "$DIR/A9CombinedRunner.dpr" -NU"$DIR" -N0"$DIR" -E"$DIR" -U"$U" -NS"$NS" ) 2>&1
rc=${PIPESTATUS[0]}
echo "BUILD_EXIT=$rc"
if [ "$rc" -ne 0 ]; then echo "== runner 编译未过 ⇒ 判据不成立 =="; exit 3; fi

echo
echo "== 真跑（合并 14 单元）$* =="
( cd "$DIR" && ./A9CombinedRunner.exe "$@" ); rc=$?
echo "RUN_EXIT=$rc"
exit $rc
