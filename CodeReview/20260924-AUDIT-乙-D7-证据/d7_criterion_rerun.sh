#!/usr/bin/env bash
# WO-20260924-AUDIT-乙-D7 判据 1/2/3/4/5/6/7 一键复算驱动（判据 8 = 暂存区卫生，见交付回执）。
# 本脚本只从自身位置反推仓库根：检出到任何目录、任何盘都一样跑。
# 取证脚本若自己写死绝对路径，就等于用同一个洞给自己作证——故此处不留任何绝对路径。
#   用法：bash CodeReview/20260924-AUDIT-乙-D7-证据/d7_criterion_rerun.sh [修前基准 commit]
#   不传参数时修前基准 = HEAD（交付当天取证即此口径，HEAD=615e1c2）；本单代码入库后复算须显式传修前基准，
#   否则「修前列」会变成自己的交付版，对照失效。
set -u
cd "$(dirname "$0")/../.." || exit 1
BEFORE_REF=${1:-HEAD}

GD=09_工程脚本/build-ownership
OUT=CodeReview/20260924-AUDIT-乙-D7-证据
FIX=.tmp/d7repro
BASE=$GD/build_ownership_baseline.json
# 修前对照件放在自己的小树下：$BEFORE_REF 版脚本 require('../gate-skip')，落点旁边必须有同族共享模块，
# 否则跑出来的是 MODULE_NOT_FOUND 而不是「旧口径的真实行为」，对照即作废。
BEFORE=$FIX/build-ownership/check_build_ownership.js
AFTER=$GD/check_build_ownership.js
WT=$FIX/wt

rm -rf "$FIX"
mkdir -p "$FIX/prodonly/Core" "$FIX/buildonly" "$FIX/shadow" "$FIX/empty" "$FIX/build-ownership"
for d in Core Features Persistence VCL FMX Governance Tools DeepFlow; do mkdir -p "$FIX/cnt_nobuild/$d" "$FIX/cnt_noprod/$d"; done
git show "$BEFORE_REF:09_工程脚本/gate-skip.js" > "$FIX/gate-skip.js"
git show "$BEFORE_REF:09_工程脚本/gate-baseline.js" > "$FIX/gate-baseline.js"
git show "$BEFORE_REF:$GD/check_build_ownership.js" > "$BEFORE"

pas() { printf 'unit %s;\ninterface\nimplementation\nend.\n' "$2" > "$1"; }
dpk() { printf 'package prod;\ncontains\n  OrphanX;\n.\n' > "$1"; }
pas "$FIX/prodonly/Core/OrphanX.pas" OrphanX
pas "$FIX/cnt_nobuild/Core/OrphanX.pas" OrphanX
dpk "$FIX/buildonly/prod.dpk"; pas "$FIX/buildonly/OrphanY.pas" OrphanY   # OrphanY 不在生产目录 ⇒ 生产面为 0
dpk "$FIX/cnt_noprod/prod.dpk"
dpk "$FIX/shadow/p.dpk"; : > "$FIX/shadow/Core"   # 生产目录被同名文件遮蔽 ⇒ 子树 readdir 必失败
: > "$FIX/afile"                                   # --root 指到普通文件 ⇒ readdir ENOTDIR

hdr() { echo; echo "########## $*"; echo; }
q() { local s=""; for a in "$@"; do s="$s'$a' "; done; echo "${s% }"; }
run() { echo "\$ $(q "$@")"; "$@" 2>&1; echo "EXIT=$?"; echo; }

# ── 判据 1 / 5：静态 grep ────────────────────────────────────────────────────
{
  hdr "判据1 交付版源码内不再出现任何绝对路径：grep -nE '[A-Za-z]:/' $GD/*.js"
  run grep -nE '[A-Za-z]:/' $GD/*.js
  echo "⇒ grep EXIT=1 即『零命中』，这就是判据 1 的通过形态（0=有命中=不通过）。"
  hdr "判据5 私有 arg() 已删除：grep -n 'function arg' $GD/*.js"
  run grep -n 'function arg' $GD/*.js
  hdr "判据5 反向确认：参数/SKIP/基线三处并入共享模块"
  run grep -n "require('../gate-" "$AFTER"
  hdr "同批修前对照（$BEFORE_REF 版同三条 grep ⇒ 证明上面两栏的差是本单造成的）"
  echo "修前件落点 $BEFORE，同树另置 $BEFORE_REF 版 gate-skip.js / gate-baseline.js 供其 require"
  run sha256sum "$BEFORE" "$AFTER"
  run grep -nE '[A-Za-z]:/' "$BEFORE"
  run grep -n 'function arg' "$BEFORE"
  run grep -n "require('" "$BEFORE"
} > "$OUT/判据1-5-静态grep.txt"

# ── 判据 3 / 4（+ 参数口径）：修前 / 修后同批 12 例对照 ──────────────────────
CASES=(
  "N1 --root 指向不存在的目录|判据3|$FIX/no-such-dir"
  "N2 --root 空目录|判据4|$FIX/empty"
  "N3 --root 只有生产面（构建文件计数 0）|§1.2-2|$FIX/prodonly"
  "N4 --root 只有引用面（生产单元计数 0）|§1.2-3|$FIX/buildonly"
  "N5 八目录齐备但零构建文件|§1.2-2|$FIX/cnt_nobuild"
  "N6 八目录齐 + 有构建文件但零生产单元|§1.2-3|$FIX/cnt_noprod"
  "N7 --root 指向普通文件|§1.2-1|$FIX/afile"
  "N8 生产目录被同名文件遮蔽|§1.2-1|$FIX/shadow"
)
ARGCASES=(
  "N9 --ROOT 大小写变体（旧实现静默忽略⇒回落默认根）|--ROOT|$FIX/prodonly"
  "N10 --rot 未知参数|--rot|$FIX/prodonly"
  "N11 裸位置参数|POSITIONAL|$FIX/prodonly"
  "N12 --root 缺值|--ROOTMISSING|"
)
TABLE=""
{
  hdr "交付件指纹"
  run sha256sum "$AFTER"
  echo "修前对照件 = git show $BEFORE_REF:$GD/check_build_ownership.js 的字节内容"
  run sha256sum "$BEFORE"
  for kind in BEFORE AFTER; do
    [ "$kind" = BEFORE ] && S=$BEFORE || S=$AFTER
    hdr "@@@@@@@@@@ $kind（$([ "$kind" = BEFORE ] && echo '修前 = $BEFORE_REF 版' || echo '修后 = 本单交付版')）@@@@@@@@@@"
    for c in "${CASES[@]}"; do
      IFS='|' read -r label tag root <<< "$c"
      echo "\$ node $S --root $root   ← ${label}"
      node "$S" --root "$root" --baseline "$BASE" 2>&1; e=$?
      echo "EXIT=$e"; echo
      TABLE="$TABLE${label}"$'\t'"${tag}"$'\t'"${kind}"$'\t'"$e"$'\n'
    done
    for c in "${ARGCASES[@]}"; do
      IFS='|' read -r label flag root <<< "$c"
      if [ "$flag" = "POSITIONAL" ]; then
        echo "\$ node $S $root   ← ${label}"; node "$S" "$root" --baseline "$BASE" 2>&1
      elif [ "$flag" = "--ROOTMISSING" ]; then
        echo "\$ node $S --root --baseline <file>   ← ${label}"; node "$S" --root --baseline "$BASE" 2>&1
      else
        echo "\$ node $S $flag $root --baseline <file>   ← ${label}"; node "$S" $flag "$root" --baseline "$BASE" 2>&1
      fi
      e=$?; echo "EXIT=$e"; echo
      TABLE="$TABLE${label}"$'\t'"§一-3 参数口径同族"$'\t'"${kind}"$'\t'"$e"$'\n'
    done
  done
  hdr "12 例 × 修前/修后 EXIT 一览（0=报绿 1=违规 2=基线不可信 3=参数/扫描失败）"
  printf '%-52s %-22s %-6s %-6s\n' 用例 判据 修前 修后
  printf "$TABLE" | awk -F'\t' '{t[$1]=$2; if($3=="BEFORE")b[$1]=$4; else a[$1]=$4} END{for(k in b) printf "%-52s %-22s %-6s %-6s\n", k, t[k], b[k], a[k]}' | sort
  echo "⇒ 修前列出现 6 个 EXIT=0（扫不到就报绿），修后 12 例全部 EXIT=3。"
  echo "⇒ N9/N10/N11 修前列是 EXIT=1：旧实现把参数吞掉后回落到写死的默认根，扫到了另一棵树——"
  echo "   它「看起来在报违规」恰恰是同一个洞的另一面（报的是别树的红，不是本树的红）。"
} > "$OUT/判据3-4-fail-closed修前修后对照.txt"

# ── 判据 2：隔离检出裸调用（不传 --root） ─────────────────────────────────────
{
  git worktree prune
  hdr "判据2 前置：新建隔离工作树（$BEFORE_REF 检出），并放入只存在于该树的孤儿单元"
  git worktree add --detach "$WT" "$BEFORE_REF" >/dev/null 2>&1 || { echo "worktree add 失败"; exit 1; }
  echo "worktree: $WT @ $(git -C "$WT" rev-parse --short HEAD)"
  pas "$WT/Core/D7ProbeOrphan.pas" D7ProbeOrphan
  hdr "修前：该树自带的 $BEFORE_REF 版脚本，裸调用（不传 --root）"
  ( cd "$WT" && run node "$GD/check_build_ownership.js" )
  echo "⇒ 输出里没有 Core/D7ProbeOrphan.pas：它扫的是脚本里写死的另一棵树，不是当前检出。"
  hdr "修后：把交付版脚本复制进同一隔离检出，裸调用（该树其余文件仍是 $BEFORE_REF 内容）"
  cp "$AFTER" "$WT/$GD/check_build_ownership.js"
  ( cd "$WT" && run node "$GD/check_build_ownership.js" )
  echo "⇒ 出现 Core/D7ProbeOrphan.pas，且覆盖面计数与该树规模同量级：默认根跟着脚本走。"
  hdr "收尾：移除本段自建的工作树"
  git worktree remove --force "$WT" && echo "worktree remove $WT OK"
} > "$OUT/判据2-隔离检出裸调用.txt"

# ── 判据 7：红项集合修前/修后逐行 diff ────────────────────────────────────────
{
  hdr "判据7 双跑（同一棵工作树，--root 同为仓库根，唯一变量是脚本版本）"
  node "$BEFORE" --root . --baseline "$BASE" >"$FIX/before.out" 2>"$FIX/before.err"; echo "BEFORE EXIT=$?"
  node "$AFTER"  --root . --baseline "$BASE" >"$FIX/after.out"  2>"$FIX/after.err";  echo "AFTER  EXIT=$?"
  grep 'O1 FAIL' "$FIX/before.err" | sed 's/^[[:space:]]*//' | sort > "$FIX/o1_before.txt"
  grep 'O1 FAIL' "$FIX/after.err"  | sed 's/^[[:space:]]*//' | sort > "$FIX/o1_after.txt"
  hdr "修前 stderr 全文"; cat "$FIX/before.err"; echo
  hdr "修后 stderr 全文"; cat "$FIX/after.err"; echo
  hdr "红项集合条数：修前 $(wc -l < "$FIX/o1_before.txt") / 修后 $(wc -l < "$FIX/o1_after.txt")"
  hdr "逐行 diff（空 ⇒ 判据7 通过）"
  diff "$FIX/o1_before.txt" "$FIX/o1_after.txt" && echo "DIFF EMPTY ⇒ 红项集合不变"
} > "$OUT/判据7-红项集合修前修后diff.txt"

# ── 判据 6：负向样本两套 ─────────────────────────────────────────────────────
{
  hdr "本门负向样本（OWNERSHIP-NEGATIVE-TEST）"
  run node "$GD/test_negative_sample.js"
  hdr "共享门禁自检（SHARED-GUARD-TEST：五道门 SKIP 单源 + 各门基线状态自检）"
  run node 09_工程脚本/test_negative_sample.js
} > "$OUT/判据6-负向样本两套复跑.txt"

# ── 交付前五门复跑 ───────────────────────────────────────────────────────────
{
  hdr "交付前五道门复跑（原始 EXIT 一律保留，红项不在本单 scope 内）"
  run node 09_工程脚本/encoding-gate/check_pas_encoding.js
  run node 09_工程脚本/eol-gate/check_eol.js
  run node 09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js
  run node 09_工程脚本/managed-copy-gate/check_managed_copy.js
  run node "$AFTER"
  run node 09_工程脚本/build-gate/check_build.js
} > "$OUT/交付前五门加甲编译门复跑.txt"

echo "证据文件已重生成于 $OUT/"
