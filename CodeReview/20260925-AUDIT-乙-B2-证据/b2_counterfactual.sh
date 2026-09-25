#!/usr/bin/env bash
# B2 反事实（变异）探针：把 SUT 里本次修掉的那一处改回错误行为，确认配套用例会真的变红。
#
# 为什么需要：只报「N passed」证明不了用例会咬人——本单判据要的是「缺陷一旦回退，测试必须红」
# （SPW A0031 反事实检查）。
# 纪律：只动工作树副本，脚本退出前一律还原（trap 覆盖正常/异常/中断），还原后再真跑一次确认回绿。
# 判定也进退出码：基线必须绿、变异必须红、还原必须绿，否则 EXIT=4——
# 探针若只把红绿印给人看而自己恒退 0，它本身就是待修的那类 fail-open 门禁。
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
# 三步各落一份完整原始输出（.txt）与一行判定（.verdict）：屏幕上只复述尾部，取证要全量
CAPDIR="$BAKDIR/capture"
mkdir -p "$CAPDIR"
run_step() {  # $1=产物基名 $2..=透传给 runner 的 DUnitX 参数
  local name="$1"; shift
  bash "$RUNNER" "$TEST_UNIT" "$@" 2>&1 | clean > "$CAPDIR/$name.txt"
  tail -20 "$CAPDIR/$name.txt"
  LC_ALL=C grep -aoE 'RUNNER_VERDICT: [A-Z_]+' "$CAPDIR/$name.txt" | tail -1 > "$CAPDIR/$name.verdict"
}
verdict_of() { cat "$CAPDIR/$1.verdict"; }

echo "==== 1) 变异前基线（应绿） ===="
run_step step1_baseline
V1="$(verdict_of step1_baseline)"

echo
echo "==== 2) 注入变异: $MUT ===="
perl -i -pe "$MUT" "$SUT" || exit 3
echo "---- 变异 diff（相对还原基线） ----"
diff -u "$BAK" "$SUT" | sed -n '3,20p'

echo "---- 变异后真跑（应红） ----"
run_step step2_mutated
V2="$(verdict_of step2_mutated)"

echo
echo "==== 3) 还原复跑（trap 之外再显式确认一次） ===="
restore
run_step step3_restored
V3="$(verdict_of step3_restored)"

# 备份留在 .tmp/b2/counterfactual/（gitignored）：trap 还要用它兜底，不在这里删
if [ "$V1" != "RUNNER_VERDICT: PASSED" ] || [ "$V2" = "RUNNER_VERDICT: PASSED" ] \
   || [ "$V3" != "RUNNER_VERDICT: PASSED" ]; then
  echo "== 反事实判定不成立：基线=$V1 变异=$V2 还原=$V3 ⇒ 用例咬不住这次修复，判据不成立 =="
  exit 4
fi
echo "== 反事实判定成立：基线绿 / 变异红($V2) / 还原绿 =="
exit 0
