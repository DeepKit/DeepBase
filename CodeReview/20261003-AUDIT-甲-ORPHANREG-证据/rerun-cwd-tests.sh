#!/usr/bin/env bash
# WO-20261003-MC-甲-ORPHANREG 判据4 纠偏：同一个 ORPHANREGOne.exe，只换 CWD 再跑一遍。
# 原探针用 `cd $dir`（scratch 目录）跑，凡带 `TFile.Exists('Core\X.pas')` 静态分析的用例
# 会因为两个候选路径都不存在而走 Assert.Pass('源文件不可访问，跳过静态分析测试') = 假绿。
# 主套件 run_tests.ps1 口径的工作目录是 Tests\（-WorkingDirectory $projectDir），
# 所以正确口径就是 CWD=Tests。本脚本对 22 个单逐个 + ALL22 工程，用同一 exe 复跑并落读数。
set -u
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

PROBES='D:/_ProgData/DeepBase-ORPHANREG/probes'
ALL22='D:/_ProgData/DeepBase-ORPHANREG/all22'
OUT='D:/_ProgData/DeepBase-ORPHANREG/probes-cwdtests'
TESTS='D:/_ProgData/DeepBase-ORPHANREG/wt-orphanreg/Tests'
mkdir -p "$OUT"

read_reading() { # read_reading <runlog> -> "Found Ignored Passed Failed Errored Leaked"
  python3 -X utf8 -c "
import io,sys
t=io.open(sys.argv[1],encoding='utf-8',errors='replace').read()
d={}
for l in t.splitlines():
    if ':' in l and l.split(':')[0].strip() in ('Tests Found','Tests Ignored','Tests Passed','Tests Failed','Tests Errored','Tests Leaked'):
        k,v=l.split(':',1); d[k.strip()]=v.strip()
print(' '.join(d.get(k,'?') for k in ['Tests Found','Tests Ignored','Tests Passed','Tests Failed','Tests Errored','Tests Leaked']))
" "$1"
}

UNITS="A8_InFlightUnloadGate BUG001_AnimationMemoryLeak BUG007_WhenReadyDeadlock BUG009_LoggingRace
BUG010_WorkerQueueRace BUG013_RSASignature BUG014_WeChatPaySignature BUG020_KeyNameValidation
BUG033_WeakEncryption BUG034_HardcodedKeys BUG035_InsecureRandom BUG037_KeyDerivation
BUG054_SemaphoreLeak BUG058_XOREncryption BUG059_JsonDeserializationType BUG060_SerializationDepth
BUG062_PluginSandbox BUG063_PluginConfigBypass BUG066_PathTraversal BUG070_LogInjection
BUG073_EventTypeInjection CR606_FrameDifferAlpha"

: > "$OUT/_rerun-summary.tsv"
printf 'unit\tCWD\tFound\tIgnored\tPassed\tFailed\tErrored\tLeaked\tRUN_EXIT\tfailing_tests\n' >> "$OUT/_rerun-summary.tsv"

run_one() { # run_one <exe> <label>
  local exe="$1" label="$2"
  local log="$OUT\\$2.run.log"
  ( cd "$TESTS" && "$exe" --exitbehavior:Continue --hidebanner ) > "$log" 2>&1
  local rc=$?
  local r; r=$(read_reading "$log")
  local fails
  fails=$(sed -n '/Failing Tests/,/Tests With Errors/p' "$log" | grep -a "^  Test\." | sed 's/^  //' | tr '\n' ';' | tr -d '\r')
  printf '%s\tTests\t%s\t%s\t%s\n' "$label" "$r" "$rc" "${fails:-}" >> "$OUT/_rerun-summary.tsv"
  printf '%-34s %s  RUN_EXIT=%s  %s\n' "$label" "$r" "$rc" "${fails:-}"
}

for u in $UNITS; do
  e="$PROBES\\$u\\ORPHANREGOne.exe"
  [ -f "$e" ] || { echo "MISSING $u"; continue; }
  run_one "$e" "$u"
done

run_one "$ALL22\\ORPHANREG22.exe" "ALL22"
echo "=== done ==="
