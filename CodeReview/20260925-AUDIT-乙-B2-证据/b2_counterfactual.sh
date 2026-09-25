#!/usr/bin/env bash
# B2 反事实（变异）探针：把 SUT 里本次修掉的那一处改回错误行为，确认配套用例会真的变红。
#
# 为什么需要：只报「N passed」证明不了用例会咬人——本单判据要的是「缺陷一旦回退，测试必须红」
# （SPW A0031 反事实检查）。
# 纪律：只动工作树副本，脚本退出前一律还原（trap 覆盖正常/异常/中断），还原后再真跑一次确认回绿。
#
# 用法: bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_counterfactual.sh <测试单元.pas> <SUT 文件.pas> '<perl -pe 表达式>'
set -u
ROOT="$(git rev-parse --show-toplevel)"
if [ "$#" -lt 3 ]; then echo "用法见脚本头部注释"; exit 3; fi
TEST_UNIT="$1"; SUT="$2"; MUT="$3"
BAKDIR="$ROOT/.tmp/b2/counterfactual"
mkdir -p "$BAKDIR"
BAK="$BAKDIR/$(basename "$SUT").bak"
cp "$SUT" "$BAK" || exit 3
restore() { cp "$BAK" "$SUT" && echo "== 已还原 SUT: $SUT =="; }
trap restore EXIT INT TERM

RUNNER="$ROOT/CodeReview/20260925-AUDIT-乙-B2-证据/b2_run_fixture.sh"
# 控制台 logger 输出中文断言消息时在本管道里落成非 UTF-8 字节（实测）；
# 证据只留纯 ASCII 行（用例名/计数/判定），中文消息按 E3 口径不落盘，避免证据自我传染。
clean() { tr -d '\r' | LC_ALL=C grep -v '[^ -~]'; }

echo "==== 1) 变异前基线（应绿） ===="
bash "$RUNNER" "$TEST_UNIT" 2>&1 | clean | tail -4

echo
echo "==== 2) 注入变异: $MUT ===="
perl -i -pe "$MUT" "$SUT" || exit 3
echo "---- 变异 diff（相对还原基线） ----"
diff -u "$BAK" "$SUT" | sed -n '3,20p'

echo "---- 变异后真跑（应红） ----"
bash "$RUNNER" "$TEST_UNIT" 2>&1 | clean | grep -E "Tests (Found|Passed|Failed|Errored|Ignored)|RUNNER_STATS|RUNNER_VERDICT|^  Test\.|BUILD_EXIT" | head -20
echo
echo "==== 3) 还原复跑（trap 之外再显式确认一次） ===="
restore
bash "$RUNNER" "$TEST_UNIT" 2>&1 | clean | tail -4
# 备份留在 .tmp/b2/counterfactual/（gitignored）：trap 还要用它兜底，不在这里删
exit 0
