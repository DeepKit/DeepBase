#!/usr/bin/env bash
# B2 单件编译探针：把【没有被任何 .dpr/.dpk 引用的孤立单元】单独喂给 dcc64，取真实红/绿。
# 为什么需要它：Screen.Click 三件与它们的测试单元不在任何构建面上（build-gate 只编 .dpr/.dpk，
# 见 09_工程脚本/build-gate/README-编译门禁.md §一），所以「该单元编译 EXIT=0」这条判据
# 在现有门禁里无处可测；本脚本只是取证探针，不是第二条构建路径（产物落 .tmp，不入库）。
#
# 用法: bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_unit_compile.sh [--with-graphics32] <相对路径.pas>...
#   --with-graphics32  追加本机 Graphics32 库源码目录到 -U（B2-05/06 的外部依赖面，见段0取证）
#
# 环境变量：DEEPBASE_BDS（Delphi 安装根，原生盘符路径）、DEEPBASE_DUNITX_SOURCE。
set -u
# MSYS 会对以 / 开头的参数值做路径改写，把 -NU/-N0/-E 的输出目录改写成不存在的混合路径
# （实测 F2039 Could not create output file 'D:C:/Users/…/.tmp/…'）。这里所有传给 dcc64 的路径
# 一律用原生盘符形式，并整体关掉改写，避免「参数被静默换脸」造成探针红绿不可信。
export MSYS2_ARG_CONV_EXCL='*'
ROOT="$(git rev-parse --show-toplevel)"          # 形如 D:/_Progs/02Business/DeepBase
BDS="${DEEPBASE_BDS:-D:/Program Files (x86)/Embarcadero/Studio/37.0}"
DCC="$BDS/bin/dcc64.exe"
DUNITX="${DEEPBASE_DUNITX_SOURCE:-D:/ProgramData/delphi/DUnitX/Source}"
G32="D:/ProgramData/delphi/graphics32/Source"
OUT="$ROOT/.tmp/b2/units"
mkdir -p "$OUT"

WITHG32=0
if [ "${1:-}" = "--with-graphics32" ]; then WITHG32=1; shift; fi
if [ "$#" -eq 0 ]; then echo "用法见脚本头部注释"; exit 3; fi

# 单元搜索面与 build-gate 的 UNIT_DIRS 同构（不在本脚本里另立一套目录清单口径，只按同一批目录取路径）
U="$ROOT/Core;$ROOT/Features;$ROOT/Persistence;$ROOT/VCL;$ROOT/FMX;$ROOT/Governance"
U="$U;$ROOT/Tests;$ROOT/Tests/Regression;$ROOT/Tests/Integration;$ROOT/DeepFlow/Source"
U="$U;$ROOT/DeepFlow/Source/Core;$ROOT/DeepFlow/Source/Workflow;$ROOT/doQry;$ROOT/ThirdParty"
U="$U;$BDS/lib/Win64/release;$DUNITX"
[ "$WITHG32" = 1 ] && U="$U;$G32"

NS="System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win"
# 与 b2_run_fixture.sh 同一口径：被编单元的 .dproj 自带 DCC_Namespace 时，探针缺省面比工程面窄会假红
# （实测 uDoQryLegacy 的 uses ADODB 需要 Data.Win，prjDoQry.dproj 的 DCC_Namespace 里有）
[ -n "${DEEPBASE_EXTRA_NS:-}" ] && NS="$NS;$DEEPBASE_EXTRA_NS"

RC_ALL=0
for f in "$@"; do
  echo "================================================================"
  echo "单元: $f   (graphics32 搜索面: $WITHG32)"
  echo "---- dcc64 原始输出 ----"
  ( cd "$ROOT" && "$DCC" -B "$f" -NU"$OUT" -N0"$OUT" -E"$OUT" -U"$U" -NS"$NS" ) 2>&1
  rc=${PIPESTATUS[0]}
  echo "BUILD_EXIT=$rc"
  [ "$rc" -ne 0 ] && RC_ALL=1
  echo
done
echo "== 汇总: 任一单元非 0 ⇒ 总 EXIT=1（本探针不吞红） => $RC_ALL =="
exit $RC_ALL
