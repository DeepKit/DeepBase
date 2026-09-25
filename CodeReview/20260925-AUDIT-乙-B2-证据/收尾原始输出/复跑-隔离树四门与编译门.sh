#!/bin/bash
# B2 收尾复验：在隔离 --detach 工作树 @ 目标 commit 上跑四门 + 编译门 T0/--all。
# 判据出处：工单 §〇-3（四门全 EXIT=0）、§〇-5（编译判据必须走隔离树，主树直跑不作判定）。
#
# 用法: bash 复跑-隔离树四门与编译门.sh [目标commit，默认 09db3c8]
# 输出：与本件同目录（覆盖上一次的原始输出件，历史值以 git 里那一笔为准）。
# 工作树用完即删——D9 §3 工作树治理口径：仓内不留游离 worktree。
set +e
REV="${1:-09db3c8}"
ROOT="$(git rev-parse --show-toplevel)"
HERE="$(cd "$(dirname "$0")" && pwd)"
WT="$ROOT/../DeepBase-wt-b2close"

git worktree add --detach "$WT" "$REV" || { echo "建隔离树失败"; exit 9; }
trap 'git worktree remove --force "$WT" 2>/dev/null; git worktree prune' EXIT

cd "$WT" || exit 9

: >"$HERE/退出码汇总.txt"
run() { # run <标签> <输出文件> <命令...>
  local label="$1" file="$2"; shift 2
  echo ">>> $label"
  "$@" >"$HERE/$file" 2>&1
  local rc=$?
  # rc 必须先落到局部变量：echo 之后再取 $? 拿到的是 echo 自己的 0（fail-open 同族坑，见乙-D7）
  echo "$label EXIT=$rc" >>"$HERE/退出码汇总.txt"
  echo "    EXIT=$rc -> $file"
}

run "gate-encoding"  "四门-@${REV:0:7}-encoding.txt"  node 09_工程脚本/encoding-gate/check_pas_encoding.js
run "gate-eol"       "四门-@${REV:0:7}-eol.txt"       node 09_工程脚本/eol-gate/check_eol.js
run "gate-mojibake"  "四门-@${REV:0:7}-mojibake.txt"  node 09_工程脚本/mojibake-gate/check_mojibake.js
run "gate-evidence"  "四门-@${REV:0:7}-evidence-encoding.txt"  node 09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js

run "build-T0"       "编译门-T0-@${REV:0:7}.txt"  node 09_工程脚本/build-gate/check_build.js --manifest 09_工程脚本/build-gate/contracts/T0-生产契约面.txt
run "build-ALL"      "编译门-all-@${REV:0:7}.txt" node 09_工程脚本/build-gate/check_build.js --all

echo "DONE $(date -Iseconds) REV=$REV" >>"$HERE/退出码汇总.txt"
