#!/usr/bin/env bash
# WO-20260924-AUDIT-乙-D9 段2：.tmp 快照目录与根目录散落件的「可逆清出」
#
# 为什么不 rm -rf：WO 的前提是「确认无保留价值后删除」。本地磁盘上的目录删了不可恢复，
# 而"价值"在这里是可机器查证的一半（有没有在册文档引用它）+ 不可查证的一半（作者本人的意图）。
# 因此只搬不删：同盘 rename 到仓外隔离区，代价近零、随时可搬回，判据 1（仓内无临时物）照样达成。
#
# 引用集口径（三处刻意的收窄/放宽，都有理由）：
#   1) HEAD 树内文件 —— 在册证据，引用即断链，算保留价值；
#   2) docs/ CodeReview/ 09_工程脚本/ 下的未跟踪非忽略文件 —— 这些是「即将落盘的本单/他单回执」，
#      本单段3 会把 R6/R7 回执纳入跟踪；若只看 HEAD，它们此刻引用的 .tmp 条目会被误判为"无人引用"，
#      落笔当天即断链（实测 .tmp/r7 正是这种假零引用）。宁宽勿漏。
#   3) 排除本单自己的 D9 证据目录 —— 取证清单逐条罗列了全部 .tmp 目录名，
#      若计入引用集，等于自己给自己开保留证明，27/40 的分类会全部失真。
set -u
MODE="${1:-dry-run}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QROOT="D:/_ProgData/DeepBase-quarantine-20260924"
OUT="$REPO/CodeReview/20260924-AUDIT-乙-D9-证据"
CUTOFF=$(date -d 2026-09-23 +%s)   # 目录内容最后活动早于此点才视为「无近期使用」
cd "$REPO" || exit 1
FIX=$(mktemp -d "${TMPDIR:-/tmp}/d9q.XXXXXX") || exit 1
trap 'rm -rf "$FIX"' EXIT

# ── 引用 token 集 ────────────────────────────────────────────────
git -c core.quotepath=false grep -I -n -oE '\.tmp/[A-Za-z0-9_.+-]+' HEAD -- \
  '*.md' '*.sh' '*.js' '*.ps1' '*.py' '*.json' '*.txt' '*.yml' '*.dpr' '*.dpk' '*.pas' \
  | sed 's/^HEAD://' >> "$FIX/raw.txt"
git ls-files --others --exclude-standard -z -- docs CodeReview 09_工程脚本 \
  | tr '\0' '\n' | grep -v '20260924-AUDIT-乙-D9-证据' > "$FIX/untracked.txt"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in *.md|*.sh|*.js|*.ps1|*.py|*.json|*.txt|*.yml) ;; *) continue ;; esac
  grep -oE '\.tmp/[A-Za-z0-9_.+-]+' "$f" 2>/dev/null | sed "s|^|$f:|" >> "$FIX/raw.txt"
done < "$FIX/untracked.txt"
grep -oE '\.tmp/[A-Za-z0-9_.+-]+' "$FIX/raw.txt" | sed 's|\.tmp/||; s|/.*||' | sort -u > "$FIX/cited.txt"

# ── 注册 worktree 集（仓内 .tmp 下的）────────────────────────────
git worktree list --porcelain | awk '/^worktree /{print $2}' | tr '\\' '/' \
  | sed "s|^$REPO/||" | awk -F/ '$1==".tmp"{print $2}' | sort -u > "$FIX/wt.txt"

# ── 逐个快照目录判定 ─────────────────────────────────────────────
: > "$FIX/move.txt"; : > "$FIX/keep.txt"
for d in .tmp/*/; do
  n=$(basename "$d")
  newest=$(find "$d" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1 | cut -d. -f1)
  [ -n "$newest" ] || newest=0
  size=$(du -sk "$d" 2>/dev/null | cut -f1)
  if grep -qxF "$n" "$FIX/cited.txt"; then
    printf '%s\tCITED\t%s\t%s\n' "$n" "$size" "$(date -d "@$newest" '+%Y-%m-%d %H:%M')" >> "$FIX/keep.txt"
  elif grep -qxF "$n" "$FIX/wt.txt"; then
    printf '%s\tWORKTREE\t%s\t%s\n' "$n" "$size" "$(date -d "@$newest" '+%Y-%m-%d %H:%M')" >> "$FIX/keep.txt"
  elif [ "$newest" -ge "$CUTOFF" ]; then
    printf '%s\tRECENT\t%s\t%s\n' "$n" "$size" "$(date -d "@$newest" '+%Y-%m-%d %H:%M')" >> "$FIX/keep.txt"
  else
    printf '%s\tSTALE\t%s\t%s\n' "$n" "$size" "$(date -d "@$newest" '+%Y-%m-%d %H:%M')" >> "$FIX/move.txt"
  fi
done

echo "# D9 段2 .tmp 清出（$(date '+%F %T') · MODE=$MODE · 判据=零引用且非worktree且内容最后活动 < 2026-09-23）"
echo "# 引用 token 总数=$(wc -l < "$FIX/cited.txt")  候选=$(wc -l < "$FIX/move.txt")  保留=$(wc -l < "$FIX/keep.txt")"
echo "# 列: 名称 / 判决 / KB / 内容最后活动"
echo "## 保留"
sort "$FIX/keep.txt"
echo "## 清出候选"
sort "$FIX/move.txt"

if [ "$MODE" = "move" ]; then
  mkdir -p "$QROOT/tmp" || exit 1
  : > "$OUT/D9-落地3b-隔离区映射清单.txt"
  while IFS=$'\t' read -r n _judgment kb mt; do
    if mv "$REPO/.tmp/$n" "$QROOT/tmp/$n" 2>"$FIX/err"; then
      printf '%s\t%s KB\t%s\t%s/.tmp/%s -> %s/tmp/%s\tMOVED\n' "$n" "$kb" "$mt" "$REPO" "$QROOT" >> "$OUT/D9-落地3b-隔离区映射清单.txt"
      echo "MOVED $n"
    else
      printf '%s\t%s KB\t%s\t%s/.tmp/%s -> (未动)\tFAILED: %s\n' "$n" "$kb" "$mt" "$(cat "$FIX/err")" >> "$OUT/D9-落地3b-隔离区映射清单.txt"
      echo "FAILED $n :: $(cat "$FIX/err")"
    fi
  done < "$FIX/move.txt"
  # 根目录散落件：同为未跟踪且被忽略，同样只搬不删
  mkdir -p "$QROOT/strays"
  for f in antitamper_debug.log compile_data005.bat; do
    [ -e "$f" ] || { echo "ABSENT $f"; continue; }
    mv "$f" "$QROOT/strays/$f" && echo "MOVED-STRAY $f" || echo "FAILED-STRAY $f"
  done
  # 根目录 .log/.bat 只登记不搬：本单无权判定他人现场，清出与否在回执里逐件申报
  find . -maxdepth 1 \( -name '*.log' -o -name '*.bat' \) -printf '%P\n' | while IFS= read -r f; do
    git ls-files --error-unmatch "$f" >/dev/null 2>&1 && echo "ROOT-TRACKED $f" || echo "ROOT-UNTRACKED-未动 $f"
  done
fi
