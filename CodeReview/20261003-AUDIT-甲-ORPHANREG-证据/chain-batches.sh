#!/usr/bin/env bash
# WO-20261003-MC-甲-ORPHANREG 判据7: chained batch merges (batch2 -> batch3).
# For each batch: apply append-only merge, verify append-only, H15 commit (options before --),
# then full-suite build+run. Stops immediately if anything looks wrong.
set -u
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

WT='D:/_ProgData/DeepBase-ORPHANREG/wt-orphanreg'
EV="CodeReview/20261003-AUDIT-甲-ORPHANREG-证据"
OUT='D:/_ProgData/DeepBase-ORPHANREG/fullsuite'
cd "$WT" || exit 2

read_reading() { # read_reading <dir> -> echoes "Found Ignored Passed Failed Errored Leaked"
  local d="$OUT\\$1"
  [ -f "$d/_reading.txt" ] || { echo "MISSING"; return 1; }
  python3 -X utf8 -c "
import io,sys
t=io.open(sys.argv[1],encoding='utf-8',errors='replace').read()
d={}
for l in t.splitlines():
    if ':' in l and l.split(':')[0].strip() in ('Tests Found','Tests Ignored','Tests Passed','Tests Failed','Tests Errored','Tests Leaked'):
        k,v=l.split(':',1); d[k.strip()]=v.strip()
print(' '.join(d.get(k,'?') for k in ['Tests Found','Tests Ignored','Tests Passed','Tests Failed','Tests Errored','Tests Leaked']))
" "$d/_reading.txt"
}

run_batch() { # run_batch <batch> <units> <before-label>
  local batch="$1" units="$2" before_label="$3"
  echo "########## $batch ##########"
  python3 -X utf8 "$EV/merge-batch.py" "$batch" || { echo "MERGE FAILED"; return 2; }
  # append-only proof: diff must contain ZERO removed lines
  local removed added
  removed=$(git diff --numstat -- Tests/DeepBaseTests.dpr | awk '{print $2}')
  added=$(git diff --numstat -- Tests/DeepBaseTests.dpr | awk '{print $1}')
  echo "dpr numstat: added=$added removed=$removed"
  if [ "$removed" != "0" ]; then echo "NOT APPEND-ONLY, aborting"; return 3; fi
  local before after
  before=$(read_reading "$before_label")
  echo "before($before_label): $before"
  git add Tests/DeepBaseTests.dpr || return 4
  git commit -m "$(cat <<EOF
test(Tests): $batch 并入 $(echo "$units" | wc -w) 个回归单（$units）

WO-20261003-MC-甲-ORPHANREG 判据7 分批表 $batch。只向 Tests/DeepBaseTests.dpr 的 uses 段追加
in 'Regression\\...' 行，numstat 证明 added-only（0 行删除）。

并入前全量（$before_label）：$before
EOF
)" -- Tests/DeepBaseTests.dpr || return 5
  git show --stat --oneline HEAD | tr -d '\r'
  bash "$EV/fullsuite-run.sh" "$batch" || { echo "RUN FAILED"; return 6; }
  after=$(read_reading "$batch")
  echo "AFTER($batch): $after"
  echo "BEFORE($before_label): $before"
}

run_batch batch2 "A8_InFlightUnloadGate BUG062_PluginSandbox BUG063_PluginConfigBypass BUG066_PathTraversal BUG070_LogInjection BUG073_EventTypeInjection" batch1 || exit $?
run_batch batch3 "BUG001_AnimationMemoryLeak BUG009_LoggingRace BUG010_WorkerQueueRace BUG054_SemaphoreLeak BUG059_JsonDeserializationType BUG060_SerializationDepth CR606_FrameDifferAlpha" batch2 || exit $?
echo "########## chain done ##########"
