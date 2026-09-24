#!/usr/bin/env bash
# WO-20260924-AUDIT-乙-D9 分支与工作树治理：取证与判据复算驱动。
# 本脚本只从自身位置反推仓库根（同族口径：取证脚本写死绝对路径 = 用同一个洞给自己作证）。
#   用法：bash CodeReview/20260924-AUDIT-乙-D9-证据/d9_governance.sh pre    # 治理前的现状取证（一次性）
#         bash CodeReview/20260924-AUDIT-乙-D9-证据/d9_governance.sh post  # 判据 1-5 复算（可随时重跑）
# 产出物 = 同目录下的 D9-*.txt，全部为 git/门禁的真实原始输出（无自报 PASS 文本）。
# 分支处置判定不在本脚本里手写：pre 段按「独有提交数 / 是否被另一保留分支包含」机器推导。
set -u
MODE="${1:-post}"
cd "$(dirname "$0")/../.." || exit 1

OUT=CodeReview/20260924-AUDIT-乙-D9-证据
mkdir -p "$OUT"
REPO=$(pwd -W 2>/dev/null || pwd)

hdr() { echo; echo "########## $*"; echo; }
q() { local s=""; for a in "$@"; do s="$s'$a' "; done; echo "${s% }"; }
run() { echo "\$ $(q "$@")"; "$@" 2>&1; echo "EXIT=$?"; echo; }

# 仓内 worktree 判据：路径以仓库根为前缀（Windows 大小写不敏感；git worktree list 用正斜杠，
# 故只统一分隔符与大小写，绝不用 cygpath -w —— 转成反斜杠会让前缀匹配恒假，仓内计数变 0 = 给自己造假 PASS）
is_main_repo() {
  local a b
  a=$(echo "$1" | tr 'A-Z' 'a-z' | tr '\\' '/'); b=$(echo "$REPO" | tr 'A-Z' 'a-z' | tr '\\' '/')
  [ "$a" = "$b" ]
}
is_inside_repo() {
  local a b
  a=$(echo "$1" | tr 'A-Z' 'a-z' | tr '\\' '/'); b=$(echo "$REPO" | tr 'A-Z' 'a-z' | tr '\\' '/')
  is_main_repo "$1" && return 1
  case "$a" in "$b"/*) return 0 ;; *) return 1 ;; esac
}

if [ "$MODE" = "pre" ]; then
# 临时件一律落仓外（本单要治理的就是"仓内杂物"；取证脚本自己往 .tmp/ 写 = 边取证边造脏）
FIX=$(mktemp -d "${TMPDIR:-/tmp}/d9.XXXXXX") || exit 1
trap 'rm -rf "$FIX"' EXIT
# ── 取证 1：分支逐一判定（WO §段1：独有提交数 = 0 ⇒ 删；禁删件照 WO 硬边界标注）──
{
  hdr "取证1 本地分支判定表（ahead=git rev-list --count master..<br>，behind 反向；cherry 的 '+' 才是 master 未含的独有提交）"
  printf '%-42s %-9s %-6s %-6s %s\n' BRANCH TIP AHEAD BEHIND 判定依据
  for b in $(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v '^master$'); do
    tip=$(git rev-parse --short "$b"); ahead=$(git rev-list --count "master..$b"); behind=$(git rev-list --count "$b..master")
    uniq=$(git cherry -v master "$b" | grep -c '^+ ')
    # 是否被另一条「非 master、非自身」的分支完全包含 ⇒ 删该分支零损失
    host=""
    if [ "$uniq" != "0" ]; then
      for o in $(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v -E "^(master|$b)$"); do
        git merge-base --is-ancestor "$b" "$o" && { host=$o; break; }
      done
    fi
    verdict="留（独有提交 $uniq，无宿主分支 ⇒ 登记待主控裁定）"
    [ "$uniq" = "0" ] && verdict="删（独有提交 0，全部已在 master）"
    [ -n "$host" ] && verdict="删（独有提交 $uniq 全部被 $host 包含 ⇒ 零损失）"
    [ "$b" = "feat/wyjx-colormatch-canary" ] && verdict="禁删（WO §段1 硬边界：载未并入 master 的 BUG-449 修复）"
    printf '%-42s %-9s %-6s %-6s %s\n' "$b" "$tip" "$ahead" "$behind" "$verdict"
    if [ "$uniq" != "0" ]; then
      echo "    └─ $b 独有提交："; git cherry -v master "$b" | grep '^+ ' | sed 's/^/       /'
    fi
  done
  hdr "取证1b de8d989（BUG-449 修复）在 master 吗 / 被哪些分支携带"
  run git merge-base --is-ancestor de8d989 master
  run git branch -a --contains de8d989
  hdr "取证1c origin 上的分支（本地删分支是否影响远端）"
  run git ls-remote --heads origin
  hdr "取证1d 各分支最后活动时间"
  git for-each-ref --format='%(refname:short) %(committerdate:short) %(contents:subject)' refs/heads/
} > "$OUT/D9-取证1-分支逐一判定.txt"

# ── 取证 2：worktree 清单（锚点可达性 + 脏度），WO §段2 要求先核可达再 remove ──
{
  hdr "取证2 git worktree list 全文 + 逐条：仓内/仓外、锚点可达性、未提交态计数"
  git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^HEAD /{print p" "$2}' > "$OUT/.wt.tmp"
  while read -r p sha; do
    kind=仓外; is_main_repo "$p" && kind=主仓; is_inside_repo "$p" && kind=仓内
    carry=$(git branch -a --contains "$sha" 2>/dev/null | tr -d ' *' | paste -sd, -)
    [ -z "$carry" ] && carry="(无分支携带，仅 reflog/锚点可达)"
    nd=$(git -C "$p" diff --numstat 2>/dev/null | wc -l)
    nu=$(git -C "$p" ls-files --others --exclude-standard 2>/dev/null | wc -l)
    printf '%-70s %s anchor=%s 未提交修改=%s 未跟踪=%s 携带分支=%s\n' "$p" "$kind" "${sha:0:7}" "$nd" "$nu" "$carry"
  done < "$OUT/.wt.tmp"
  rm -f "$OUT/.wt.tmp"
  hdr "取证2b 仓内 worktree 清单与数量（WO 判据 1 治理前基线；主仓不计）"
  git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r p; do is_inside_repo "$p" && echo "$p"; done > "$OUT/.inside.tmp"
  wc -l < "$OUT/.inside.tmp"
  cat "$OUT/.inside.tmp"
  rm -f "$OUT/.inside.tmp"
  hdr "取证2c 脏 worktree 的未提交态逐件定性：剥掉 UTF-8 BOM 与 CR 后是否与该分支 HEAD 逐字节相等"
  echo "只有 BOM/行尾增删 ⇒ 未提交态是机械编码规范化（G3 面），不含独有语义；否则逐件点名。"
  echo "口径说明：这些 worktree 停在旧提交（.gitattributes 尚无 *.pas text eol=crlf），git 不做归一，"
  echo "所以必须自己剥 BOM + CR 再比；不剥就会把 343 件机械噪音读成 343 件独有工作（假阳性）。"
  for wt in .claude/worktrees/perception-p2 .claude/worktrees/wyjx-colormatch-canary .tmp/wt_a1_8be7def; do
    [ -d "$wt" ] || continue
    bomonly=0; other=0; otherlist=""
    while IFS= read -r f; do
      [ -f "$wt/$f" ] || { other=$((other+1)); otherlist="$otherlist"$'\n'"    非噪音：$f（工作树缺件/删除/非普通文件）"; continue; }
      bhash=$(git -C "$wt" rev-parse "HEAD:$f" 2>/dev/null)
      [ -n "$bhash" ] || { other=$((other+1)); otherlist="$otherlist"$'\n'"    非噪音：$f（该分支 HEAD 无此件 = 新增内容）"; continue; }
      # 剥 BOM（首 3 字节 efbbbf）→ 剥行尾 CR → 与 HEAD blob 逐字节 cmp
      if [ "$(head -c 3 "$wt/$f" | xxd -p)" = "efbbbf" ]; then tail -c +4 "$wt/$f" > "$FIX/nb"; else cat "$wt/$f" > "$FIX/nb"; fi
      tr -d '\r' < "$FIX/nb" > "$FIX/nb2"
      if git -C "$wt" cat-file blob "$bhash" | cmp -s - "$FIX/nb2"; then
        bomonly=$((bomonly+1))
      else
        other=$((other+1)); otherlist="$otherlist"$'\n'"    非噪音：$f"
      fi
    done < <(git -C "$wt" diff --name-only)
    printf '%-46s BOM或行尾噪音=%s 其他=%s\n' "$wt" "$bomonly" "$other"
    printf '%s\n' "$otherlist"
    echo "    未跟踪件：$(git -C "$wt" ls-files --others --exclude-standard | tr '\n' ' ')"
  done
  hdr "取证2d 脏 worktree 逐件四路哈希（工作树字节 / master 同名件 / 该分支 HEAD）"
  for f in Core/DeepBase.Authorization.pas Tools/CLI/CLI.Security.pas Tests/Test.DeepBase.Desktop.Perception.FrameCache.pas; do
    for wt in .claude/worktrees/perception-p2 .claude/worktrees/wyjx-colormatch-canary .tmp/wt_a1_8be7def; do
      [ -f "$wt/$f" ] || continue
      wthash=$(git -C "$wt" hash-object "$f" 2>/dev/null)
      mhash=$(git rev-parse "master:$f" 2>/dev/null || echo 不在master)
      bhash=$(git -C "$wt" rev-parse "HEAD:$f" 2>/dev/null || echo 不在该分支)
      printf '%-46s %-52s wt=%s master=%s 该分支HEAD=%s\n' "$wt" "$f" "${wthash:0:8}" "${mhash:0:8}" "${bhash:0:8}"
    done
  done
  hdr "取证2e .tmp 下 worktree 的 .git 指针（确认是 git worktree 而非普通副本）"
  for d in $(git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | grep -F "$REPO/.tmp"); do
    printf '%-58s ' "$d"; head -c 120 "$d/.git" 2>/dev/null | tr '\n' ' '; echo
  done
} > "$OUT/D9-取证2-worktree清单与锚点.txt"

# ── 取证 3：假脏判定（WO §段3 的前提：12 件 .pas 内容与 HEAD 逐字节一致）──────
{
  hdr "取证3 当前 git status 已跟踪条目全集（分类：' M'=工作树 vs 索引 差异，'M '=索引 vs HEAD）"
  run git -c core.quotepath=false status --porcelain --untracked-files=no
  hdr "取证3b 逐件四路哈希：raw(不过筛) / filtered(--path 过 .gitattributes) / index blob / HEAD blob"
  echo "四值全等 ⇒ 内容与 HEAD 无任何差异，脏位纯属 stat 噪音（WO §段3 的「行尾假脏」）。"
  for f in $(git -c core.quotepath=false status --porcelain --untracked-files=no | grep -E '^ M' | sed 's/^ M //'); do
    r=$(git hash-object -- "$f"); fl=$(git hash-object --path "$f" -- "$f")
    i=$(git ls-files -s -- "$f" | awk '{print $2}'); h=$(git rev-parse "HEAD:$f")
    if [ "$r" = "$h" ] && [ "$fl" = "$h" ] && [ "$i" = "$h" ]; then v="假脏(4路全等)"; else v="真差异"; fi
    ndiff=$(git diff --numstat -- "$f" | wc -l)
    printf '%-62s %-14s diff行数=%s  raw=%s filt=%s index=%s head=%s\n' "$f" "$v" "$ndiff" "${r:0:8}" "${fl:0:8}" "${i:0:8}" "${h:0:8}"
  done
  hdr "取证3c 真差异件（本单不得替他人落笔，逐件点名归属）"
  git -c core.quotepath=false diff --name-only --diff-filter=d | while read -r f; do
    printf '%-62s diffstat=%s\n' "$f" "$(git diff --numstat -- "$f" | awk '{print "+"$1" -"$2}')"
  done
  hdr "取证3d .gitignore 现状：.ai/ .superpowers/ Scripts/__pycache__/ 是否已被忽略（改前须 EXIT=1）"
  run git check-ignore -v .ai .superpowers Scripts/__pycache__ .workbuddy
} > "$OUT/D9-取证3-假脏与真差异逐件哈希.txt"

# ── 取证 4：.tmp 快照与根目录散落件（WO §段2）───────────────────────────────
{
  hdr "取证4 .tmp 清点（条目数 / 目录数 / 总体积 / 其中 git worktree 数）"
  printf '条目 %s 个（其中目录 %s 个）\n' "$(ls -1 .tmp | wc -l)" "$(find .tmp -maxdepth 1 -type d | tail -n +2 | wc -l)"
  run du -sh .tmp
  printf '注册为 git worktree 的 .tmp 目录 %s 个\n' "$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | grep -cF "$REPO/.tmp")"
  hdr "取证4b .tmp 顶层目录逐个体积（体积即保留价值的粗筛，非判据）"
  run du -sh .tmp/*/
  hdr "取证4c 根目录散落件（被 .gitignore 吞掉、从不入库的本地产物）"
  run ls -1 *.log *.bat 2>/dev/null
  hdr "取证4d 这些散落件是否被跟踪（跟踪=0 才可安全清掉；被跟踪则须先按门禁口径处置）"
  for f in $(ls -1 *.log *.bat 2>/dev/null); do printf '%-32s tracked=%s ignored=%s\n' "$f" "$(git ls-files --error-unmatch "$f" >/dev/null 2>&1 && echo YES || echo NO)" "$(git check-ignore -q "$f" && echo YES || echo NO)"; done
} > "$OUT/D9-取证4-tmp与根目录散落件.txt"
  echo "pre 取证完成："; ls -1 "$OUT" | sed 's/^/  /'
  exit 0
fi

# ── 取证4e：.tmp 顶层条目「被在册文档引用」vs「无人引用」分类 ─────────────────
# WO §段2 的前提是「.tmp 快照确认无保留价值后删除」。此段把"价值"可查证的那一半做出来：
# 只要在册文件引用了 .tmp/<名>，删掉就等于让验收证据断链 —— 不算无保留价值。
# 口径：引用集只从 HEAD 树里取（git grep <rev>），本单自己新写的取证文件尚未入库，
# 不能引用一次就给自己"造保留价值"（否则此判据永远自证成立）。
if [ "$MODE" = "tmpcites" ]; then
  FIX=$(mktemp -d "${TMPDIR:-/tmp}/d9.XXXXXX") || exit 1
  trap 'rm -rf "$FIX"' EXIT
  {
    hdr "取证4e .tmp 顶层条目分类：被 HEAD 树内在册文件引用的 vs 无人引用的"
    PS1_="'*.md' '*.sh' '*.js' '*.ps1' '*.py' '*.json' '*.txt'"
    echo "\$ git grep -I -n -oE '\.tmp/[A-Za-z0-9_.+-]+' HEAD -- $PS1_   # 单次全树扫描，下游用 awk 聚合"
    # -n 必须带：git grep 指定 rev 时输出 = HEAD:<path>:<行号>:<命中>；漏 -n 会得到 HEAD:<path>:<命中>，
    # 下面按 ":行号:" 切分的 awk 会整体失配并把路径前缀误当成 token（实测曾输出 209 CodeReview 这种假计数）。
    git -c core.quotepath=false grep -I -n -oE '\.tmp/[A-Za-z0-9_.+-]+' HEAD -- '*.md' '*.sh' '*.js' '*.ps1' '*.py' '*.json' '*.txt' \
      | sed 's/^HEAD://' > "$FIX/raw.txt"
    # git grep 指定 rev 时输出格式 = <path>:<行号>:<命中文本>；行号是纯数字段，据此切分
    awk '{p=$0; sub(/:[0-9]+:.*$/,"",p); t=$0; sub(/^.*:[0-9]+:/,"",t); print p"\t"t}' "$FIX/raw.txt" > "$FIX/pt.txt"
    awk -F'\t' '{n=$2; sub(/^\.tmp\//,"",n); sub(/\/.*/,"",n); key=$1"\t"n; if(!(s[key]++)) c[n]++} END{for(t in c) print c[t]"\t"t}' "$FIX/pt.txt" | sort -rn > "$FIX/cited-count.txt"
    cut -f2 "$FIX/cited-count.txt" | sort > "$FIX/cited.txt"
    echo "HEAD 树内引用过的 .tmp/<名> token 数: $(wc -l < "$FIX/cited.txt")（下表数字=引用它的不同在册文件数；Top 20：）"
    head -20 "$FIX/cited-count.txt"
    echo
    printf '%-30s %-24s %-18s %s\n' 条目 引用它的在册文件数 最后活动stat 注册worktree
    git worktree list --porcelain | awk '/^worktree /{print $2}' | tr 'A-Z' 'a-z' | tr '\\' '/' > "$FIX/wtlist"
    for d in .tmp/*/; do
      n=$(basename "$d")
      c=$(awk -F'\t' -v k="$n" '$2==k{print $1; f=1} END{if(!f) print 0}' "$FIX/cited-count.txt")
      mt=$(stat -c '%y' "$d" | cut -c1-16)
      isw=$(grep -qix "$REPO/.tmp/$n" "$FIX/wtlist" 2>/dev/null && echo WORKTREE || echo -)
      printf '%-30s %-24s %-18s %s\n' "$n" "$c" "$mt" "$isw"
    done
    echo
    echo "-- 引用 .tmp 的在册文件（HEAD 树，去重后全量）"
    cut -f1 "$FIX/pt.txt" | sort -u
  } > "$OUT/D9-取证4e-tmp条目引用分类.txt" 2>&1
  echo "取证4e 完成：$OUT/D9-取证4e-tmp条目引用分类.txt"
  exit 0
fi

# ══ post：WO §判据 1-5 复算 ═════════════════════════════════════════════════
{
  hdr "判据1 git worktree list 中不得有任何位于仓库目录内部（列出全部 + 仓内计数）"
  echo "口径：主仓自身单独标注，不算仓外工作树；判据只看「除主仓外是否有路径落在仓库目录内部」"
  git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r p; do
    is_inside_repo "$p" && echo "仓内（违规）：$p" || { is_main_repo "$p" && echo "主仓（不计）：$p" || echo "仓外（允许）：$p"; }
  done
  INSIDE=$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r p; do is_inside_repo "$p" && echo "$p"; done | wc -l)
  echo "⇒ 仓内 worktree 计数 = $INSIDE（须为 0）"
  hdr "判据1b .tmp 是否仍存留（WO §段2：快照目录不得留在仓库内部）"
  run ls -d .tmp
  hdr "判据2a upgrade/delphi-13 必须不存在"
  run git rev-parse --verify upgrade/delphi-13
  hdr "判据2b README 必须有「消费者应使用哪个分支」一节"
  run grep -nE '^#+ .*(分支|Branch)' README.md
  hdr "判据2c 现存本地分支（治理后）"
  git for-each-ref --format='%(refname:short) %(committerdate:short)' refs/heads/
  hdr "判据3 已跟踪文件的 git status 必须为空（非空则逐条点名归属）"
  run git -c core.quotepath=false status --porcelain --untracked-files=no
  hdr "判据3b 该空的三类未跟踪噪声是否已入门禁口径（check-ignore 须 EXIT=0）"
  run git check-ignore -v .ai .superpowers Scripts/__pycache__
  hdr "判据4 feat/wyjx-colormatch-canary 未被擅删 + de8d989 仍未并入 master（待主控裁定）"
  run git rev-parse --verify feat/wyjx-colormatch-canary
  run git merge-base --is-ancestor de8d989 master
  echo "⇒ 上一条 EXIT=1 即「BUG-449 修复仍未进 master」，与回执 §登记 一致（处置权在主控）。"
  hdr "判据5 落笔前暂存区（须与回执 §申报清单 逐件相等，由主控比对）"
  run git -c core.quotepath=false diff --cached --name-only
  hdr "收尾 五道静态门禁复跑（本单只动 .gitignore/README/docs，不碰门禁；红项照实保留）"
  run node 09_工程脚本/encoding-gate/check_pas_encoding.js
  run node 09_工程脚本/eol-gate/check_eol.js
  run node 09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js
  run node 09_工程脚本/managed-copy-gate/check_managed_copy.js
  run node 09_工程脚本/build-ownership/check_build_ownership.js
  hdr "落笔后自证 本单新建证据件是否进入 E3 命中面（须 0 行，否则 = 用「自己的证据」给自己造存量）"
  echo "口径：本门默认只扫索引里的已跟踪证据 ⇒ 必须在 git add 本单全部产出之后跑；--list-mojibake 给出命中件全清单，逐件路径可见。"
  MB=$(node 09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js --list-mojibake 2>&1); echo "EXIT=$?"
  printf '%s\n' "$MB" | grep '^#'
  SELF=$(printf '%s\n' "$MB" | grep -c 'AUDIT-乙-D9'); echo "本单目录在命中清单中的行数 = $SELF（判据：0）"
  echo "命中清单总行数（= 存量件数，与门禁汇总 K 件对账）：$(printf '%s\n' "$MB" | grep -vc '^#')"
} > "$OUT/D9-判据1-5-复算原始输出.txt"
echo "post 复算完成：$OUT/D9-判据1-5-复算原始输出.txt"
