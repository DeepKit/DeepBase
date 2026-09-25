#!/usr/bin/env bash
# B2 fixture 子集真跑探针：一次性 DUnitX 控制台 runner，只挂入指定的测试单元。
#
# 为什么自建 runner：WO §〇-4 明写「不要改 Tests/DeepBaseTests.dpr/.dproj 注册（归主控收口）」，
# 而「用例绿」这条判据必须真跑出来的原始输出作证据（非睿智轻量门禁 G2：禁止仅自报 PASS）。
# 产物全部落 .tmp（gitignored），本脚本不是第二条构建路径，注册收口仍由主控在同一 runner 语义下完成。
#
# 三道 fail-closed（缺一即红，不接受「跑起来了就算绿」）：
#   1. 编译非 0 ⇒ RUN_EXIT=3；
#   2. TotalTests=0 ⇒ RUN_EXIT=2（假 fixture / 过滤器 0 命中，正是 B2 这批测试单元的原始缺陷形态）；
#   3. 任一用例未过 ⇒ RUN_EXIT=1。
#
# 用法: bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_run_fixture.sh <Tests/xxx.pas> [DUnitX 参数，如 --filter ...]
set -u
# 同 b2_unit_compile.sh：MSYS 会改写以 / 开头的参数值，dcc64 的输出目录参数一律给原生盘符路径并关掉改写。
export MSYS2_ARG_CONV_EXCL='*'
ROOT="$(git rev-parse --show-toplevel)"
BDS="${DEEPBASE_BDS:-D:/Program Files (x86)/Embarcadero/Studio/37.0}"
DCC="$BDS/bin/dcc64.exe"
DUNITX="${DEEPBASE_DUNITX_SOURCE:-D:/ProgramData/delphi/DUnitX/Source}"

if [ "$#" -lt 1 ]; then echo "用法见脚本头部注释"; exit 3; fi
UNIT_FILE="$1"; shift
[ -f "$UNIT_FILE" ] || { echo "测试单元不存在: $UNIT_FILE"; exit 3; }
UNIT_NAME="$(basename "$UNIT_FILE" .pas)"     # 仓内约定：文件名即单元名
DIR="$ROOT/.tmp/b2/runner/$UNIT_NAME"
# 清不干净就停：残留的上一次 exe/dcu 会让这一轮的绿不是本轮代码的绿
rm -rf "$DIR" || { echo "无法清空探针目录（占用中？）: $DIR"; exit 3; }
mkdir -p "$DIR"

# 模板本体是 CRLF（与仓内 .dpr 同行尾），sed 只替换单元名占位符，不动行尾
# 模板刻意不带 {$R *.res}：一次性 runner 没有 IDE 生成的版本资源，留着会编成 E1026 File not found
sed "s/__UNIT__/$UNIT_NAME/" \
  "$ROOT/CodeReview/20260925-AUDIT-乙-B2-证据/附件/B2FixtureRunner.dpr" > "$DIR/B2FixtureRunner.dpr"

echo "== 编译一次性 runner（单元: $UNIT_NAME） =="
# 搜索面与 b2_unit_compile.sh 同一批目录口径，不另立一套
U="$ROOT/Core;$ROOT/Features;$ROOT/Persistence;$ROOT/VCL;$ROOT/FMX;$ROOT/Governance"
U="$U;$ROOT/Tests;$ROOT/Tests/Regression;$ROOT/Tests/Integration;$ROOT/DeepFlow/Source"
U="$U;$ROOT/DeepFlow/Source/Core;$ROOT/DeepFlow/Source/Workflow;$ROOT/doQry;$ROOT/ThirdParty"
U="$U;$BDS/lib/Win64/release;$DUNITX"
# 邻件回归要跑不在标准搜索面上的目录（如 DeepFlow/Tests）时用它追加，不另立一套口径
[ -n "${DEEPBASE_EXTRA_U:-}" ] && U="$U;$DEEPBASE_EXTRA_U"
NS="System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win"
( cd "$ROOT" && "$DCC" -B "$DIR/B2FixtureRunner.dpr" -NU"$DIR" -N0"$DIR" -E"$DIR" -U"$U" -NS"$NS" ) 2>&1
rc=${PIPESTATUS[0]}
echo "BUILD_EXIT=$rc"
if [ "$rc" -ne 0 ]; then echo "== runner 编译未过 ⇒ 判据不成立 =="; exit 3; fi

echo
echo "== 真跑（$UNIT_NAME）$* =="
# 必须在 .tmp 下跑：exe 的相对路径依赖 cwd，且避免测试产物写进工作树
# rc 必须先落到变量再打印：echo 之后 $? 就变成 echo 自己的 0，
# 那是「门禁只报不拦」的 fail-open（同族缺陷见 WO-20260924-AUDIT-乙-D7）
( cd "$DIR" && ./B2FixtureRunner.exe "$@" ); rc=$?
echo "RUN_EXIT=$rc"
exit $rc
