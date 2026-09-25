#!/bin/bash
# B2 收尾·归因复跑（两件分开做，缺一件就只剩「整面聚合数字」而落不到具体包）：
#  A) T0 同一清单、同一噪声基线，在「工单基准 92c14d1」与「甲 A2 验收+并网 347b126」两点各跑一遍
#     ⇒ 把噪声门 H2077/H2443 的增长按【逐工程 HINT/WARN】落到具体工程，再与本单末笔对比。
#  B) --all 全量面在 92c14d1 跑一遍 ⇒ 与交付树红集合做双向差集，证明「零新增编译红」或点名新增的那件。
#
# 用法: bash 复跑-噪声与红集合归因.sh [工单基准] [中间笔]
# 输出件与本件同目录；隔离树用完即删（D9 §3）。
set +e
BASE="${1:-92c14d1}"
MID="${2:-347b126}"
M=09_工程脚本/build-gate/contracts/T0-生产契约面.txt
ROOT="$(git rev-parse --show-toplevel)"
HERE="$(cd "$(dirname "$0")" && pwd)"

: >"$HERE/退出码汇总-归因.txt"
wtrun() { # wtrun <目录名> <rev> <输出文件> <门禁参数...>
  local dir="$1" rev="$2" out="$3"; shift 3
  local wt="$ROOT/../$dir"
  git worktree add --detach "$wt" "$rev" || { echo "worktree add $rev 失败" >>"$HERE/退出码汇总-归因.txt"; return; }
  ( cd "$wt" && node 09_工程脚本/build-gate/check_build.js "$@" >"$HERE/$out" 2>&1 )
  echo "$(basename "$out" .txt) EXIT=$?" >>"$HERE/退出码汇总-归因.txt"
  git worktree remove --force "$wt" 2>/dev/null
}

wtrun DeepBase-wt-b2noise-base "$BASE" "归因-编译门-T0-@$BASE.txt"  --manifest "$M"
wtrun DeepBase-wt-b2noise-base "$BASE" "归因-编译门-all-@$BASE.txt" --all
wtrun DeepBase-wt-b2noise-mid  "$MID"  "归因-编译门-T0-@$MID.txt"   --manifest "$M"
git worktree prune
echo "ATTR DONE $(date -Iseconds) base=$BASE mid=$MID" >>"$HERE/退出码汇总-归因.txt"
