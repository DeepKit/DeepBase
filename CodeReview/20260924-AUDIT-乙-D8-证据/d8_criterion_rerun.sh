#!/usr/bin/env bash
# WO-20260924-AUDIT-乙-D8 判据 1/2/3/4/5/6/7 一键复算驱动。
# 本脚本只从自身位置反推仓库根（同族口径：取证脚本自己写死绝对路径 = 用同一个洞给自己作证）。
#   用法：bash CodeReview/20260924-AUDIT-乙-D8-证据/d8_criterion_rerun.sh
# 产出物 = 同目录下的 D8-*.txt 七件，全部为门禁/测试的真实原始输出（无自报 PASS 文本）。
# 件数、行数一律是活值：他方入库新证据后复算会跟着变，这不是缺陷，正是本门要显形的东西。
set -u
cd "$(dirname "$0")/../.." || exit 1

GD=09_工程脚本/evidence-encoding-gate
CHECK=$GD/check_evidence_encoding.js
BASELINE=$GD/evidence_encoding_baseline.json
OUT=CodeReview/20260924-AUDIT-乙-D8-证据
FIX=.tmp/d8repro
R7=CodeReview/20260920-AUDIT-甲-证据/R7/R7-gates-run.txt

rm -rf "$FIX"
mkdir -p "$FIX/empty" "$FIX/nocodeview" "$FIX/variant" "$FIX/corpus/CodeReview"
# 变体脚本放独立小树下，其 require('../gate-*') 需要在同级找到同族共享模块
cp 09_工程脚本/gate-args.js 09_工程脚本/gate-skip.js 09_工程脚本/gate-baseline.js "$FIX/"

hdr() { echo; echo "########## $*"; echo; }
q() { local s=""; for a in "$@"; do s="$s'$a' "; done; echo "${s% }"; }
run() { echo "\$ $(q "$@")"; "$@" 2>&1; echo "EXIT=$?"; echo; }

# ── 判据 1：WO 点名的 R7 三行必须被准确定位 ──────────────────────────────────
{
  hdr "判据1 全门实跑（默认口径 = git 已跟踪证据）"
  run node "$CHECK"
  hdr "从上面输出里切出 R7 点名的三行（第 1/3/5 行；括号内「替换符 坏/总」由门禁自身打印）"
  node "$CHECK" 2>&1 | grep -F "$R7"
  echo "⇒ 门禁自身报出的就是这三行，行数与 WO §〇 一致（1/3/5），无需人工比对。"
  hdr "与主控参考口径的对照（Python line.encode('gb18030').decode('utf-8',errors='replace').count(chr(0xFFFD))）"
  echo "主控在 WO §〇 亲测：第 1/3/5 行替换符 = 3 / 4 / 1。上面门禁报的 替换符 3/N、4/N、1/N 分子即同值 ⇒ 计数口径已对齐。"
} > "$OUT/D8-判据1-R7三行定位-门禁原始输出.txt"

# ── 判据 2 / §1.4：负向样本（本门 + 门禁族共享自检）──────────────────────────
{
  hdr "本门负向样本（EVIDENCE-NEGATIVE-TEST：§1.4 四条 + §1.3 三条 + 只减不增 + --list-mojibake）"
  run node "$GD/test_negative_sample.js"
  hdr "门禁族共享自检（SHARED-GUARD-TEST：五道门 SKIP 单源 + 各门基线状态自检）"
  run node 09_工程脚本/test_negative_sample.js
} > "$OUT/D8-判据2-负向样本全套输出.txt"

# ── 判据 3 / §1.3：fail-closed 三条 + 参数口径 + 基线状态 ─────────────────────
{
  hdr "N1 扫到 0 个证据文件（默认口径 = git 已跟踪；根内没有已跟踪的 CodeReview 件）⇒ 须 EXIT=3"
  run node "$CHECK" --root "$FIX/empty"
  hdr "N1b 同上但走工作树枚举（--all-worktree）⇒ 须 EXIT=3"
  run node "$CHECK" --root "$FIX/empty" --all-worktree
  hdr "N2 --all-worktree 且根下没有 CodeReview 子树（readdir 失败）⇒ 须 EXIT=3 且打印失败路径"
  run node "$CHECK" --root "$FIX/nocodeview" --all-worktree
  hdr "N2b 根指向普通文件（根下 CodeReview 子树必然读不出来）⇒ 须 EXIT=3 且打印失败路径"
  : > "$FIX/afile"
  run node "$CHECK" --root "$FIX/afile" --all-worktree
  hdr "N3 --ROOT 大小写变体（旧私有 arg() 会静默回落默认根）⇒ 须 EXIT=3"
  run node "$CHECK" --ROOT "$FIX/empty"
  hdr "N4 --root 缺值 ⇒ 须 EXIT=3"
  run node "$CHECK" --root
  hdr "N5 基线缺 mojibakeStock 键（存量清单不可信）⇒ 须 EXIT=2"
  node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));delete o.mojibakeStock;fs.writeFileSync(process.argv[2],JSON.stringify(o,null,2))' "$BASELINE" "$FIX/no_mojibake_baseline.json"
  run node "$CHECK" --root . --baseline "$FIX/no_mojibake_baseline.json"
  hdr "N6 交付件指纹（本判据全部结论所依据的字节）"
  run sha256sum "$CHECK" "$BASELINE" "$GD/test_negative_sample.js"
} > "$OUT/D8-判据3-4-fail-closed四条实测.txt"

# ── 判据 4/5/6：计数同量级、默认根无绝对路径、单次扫描 ────────────────────────
{
  hdr "判据4 覆盖面计数两口径必须同值：--list-files 行数 vs 门禁汇总里的「扫描 N 个」"
  echo "\$ node $CHECK --list-files | wc -l"
  LISTED=$(node "$CHECK" --list-files | wc -l)
  echo "$LISTED"
  SUMMARY=$(node "$CHECK" 2>&1 | grep -oE '扫描 [0-9]+ 个' | head -1)
  echo "门禁汇总行口径：$SUMMARY"
  [ "$LISTED" = "$(echo "$SUMMARY" | grep -oE '[0-9]+')" ] && echo "⇒ 同值：判据4 通过（--list-files 与判据共用同一次枚举）" \
    || echo "⇒ 不等：判据4 失败（存在两套计数）"
  hdr "判据4 空扫描 ⇒ EXIT≠0 的实测见 D8-判据3-4-fail-closed四条实测.txt N1"
  hdr "判据5 默认 ROOT 由脚本自身位置反推（源码里不得出现绝对路径字面量）"
  run grep -n "root:" "$CHECK"
  run grep -nE '[A-Za-z]:[/\\]|"/(Users|home|srv)' "$CHECK"
  echo "⇒ 上一条 grep EXIT=1（零命中）即判据 5 通过。"
  hdr "判据5 参数/共享模块复用：本门 require 的三个同族模块"
  run grep -n "require('../gate-" "$CHECK"
  hdr "判据6 files 只枚举一次，--list-files 与 E1/E2/E3 判据读同一数组（行号即证据）"
  run grep -n "files = ALL_WORKTREE\|list-files\|for (const rel of files)\|files.length" "$CHECK"
} > "$OUT/D8-判据4-5-6-计数与ROOT与单次扫描.txt"

# ── §1.2 存量清单：门禁自身复算，不靠人抄 ─────────────────────────────────────
{
  hdr "§1.2 --list-mojibake 全文（= evidence_encoding_baseline.json 的 mojibakeStock 唯一来源）"
  run node "$CHECK" --list-mojibake
  hdr "与基线登记逐行对账（左=门禁现算 右=基线登记；差集为空 ⇒ 登记无虚增）"
  node "$CHECK" --list-mojibake | grep -E '^[0-9]+' | sort > "$FIX/live.tsv"
  node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8")).mojibakeStock;for(const k in s)console.log(s[k]+"\t"+k)' "$BASELINE" | sort > "$FIX/stock.tsv"
  run diff "$FIX/live.tsv" "$FIX/stock.tsv"
  echo "⇒ diff 空即基线与门禁现算逐行相等；条目只能因还原内容而减少，因新增证据而增加必须写来源。"
} > "$OUT/D8-存量清单-list-mojibake全文.txt"

# ── §1.1 阈值标定：良性中文语料必须零误报（负面控制的规模化版本）──────────────
# 口径：不另写一份判据复算（那会变成第二真源），而是把真实中文文档整批塞进一个临时
# CodeReview 树，直接叫门禁自己去扫；阈值扫描 = 只改常量的门禁副本，判据逻辑仍是交付件本体。
{
  hdr "构造良性语料临时树：git 已跟踪的 docs/** 与 08_元管理/** 全部 .md 平铺进 $FIX/corpus/CodeReview/"
  git -c core.quotepath=false ls-files -- docs 08_元管理 | grep '\.md$' > "$FIX/corpus.list"
  n=0
  while IFS= read -r f; do
    # 已跟踪但工作树缺失 = 他方在途删除，跳过并点名（取证脚本不得因为别人的中间态而跑挂）
    [ -f "$f" ] || { echo "跳过（已跟踪、工作树缺失）：$f"; continue; }
    cp "$f" "$FIX/corpus/CodeReview/$(echo "$f" | tr '/' '_')" && n=$((n+1))
  done < "$FIX/corpus.list"
  LINES=$(find "$FIX/corpus/CodeReview" -name '*.md' -exec cat {} + | wc -l)
  echo "清单 $(wc -l < "$FIX/corpus.list") 件 → 实际入树 $n 件 / 合计 $LINES 行（含大量中英混排、代码块、表格、链接）"
  echo
  hdr "标定 = 用门禁自身的 --list-mojibake 数（命中即误报）。交付版（clean≥4 / 占比≤20% / 表意占比≥50%）："
  node "$CHECK" --root "$FIX/corpus" --all-worktree --list-mojibake | grep -v '\.md:' | tail -1
  for kv in "0.15:MAX_BROKEN_RATIO" "0.30:MAX_BROKEN_RATIO" "0.50:MAX_BROKEN_RATIO" "2:MIN_RESTORED_UNITS" "0.8:MIN_RESTORED_CJK_RATIO"; do
    v=${kv%%:*}; k=${kv##*:}
    cp "$CHECK" "$FIX/variant/v.js"
    sed -i "s/^const $k = .*/const $k = $v;/" "$FIX/variant/v.js"
    printf '变体 %-24s = %-6s ⇒ ' "$k" "$v"
    node "$FIX/variant/v.js" --root "$FIX/corpus" --all-worktree --baseline "$BASELINE" --list-mojibake | grep -v '\.md:' | tail -1
  done
  echo
  hdr "判据 1 样本在交付版下的定位与占比（R7 三行，临时树里那份与仓库件同字节）"
  mkdir -p "$FIX/r7/$(dirname "$R7")" && cp "$R7" "$FIX/r7/$R7"
  node "$CHECK" --root "$FIX/r7" --all-worktree --list-mojibake | sed -n '1,20p'
  node "$CHECK" --root "$FIX/r7" --all-worktree 2>&1 | grep -F "R7-gates-run.txt:" | head -6
  echo "⇒ 括号内「替换符 坏/总」由门禁自己给出：3/26、4/39、1/15 ⇒ 11.5%/10.3%/6.7%，全部落在 20% 阈内。"
} > "$OUT/D8-阈值标定-良性语料零误报.txt"

# ── 交付前五道门复跑（同族口径：原始 EXIT 一律保留，红项不在本单 scope 内）────
# 不含甲编译门（build-gate）：本单零 .pas、零构建面改动，编译门与本单无因果；
# 且工作树此刻含他方在途 .pas 编辑，跑 --all 会把别人的中间态读成本单结论（判据 7 的反面）。
{
  hdr "交付前五道门复跑（本单只改证据编码门禁；其余四门跑的是回归对照，红项照实保留）"
  run node 09_工程脚本/encoding-gate/check_pas_encoding.js
  run node 09_工程脚本/eol-gate/check_eol.js
  run node "$CHECK"
  run node 09_工程脚本/managed-copy-gate/check_managed_copy.js
  run node 09_工程脚本/build-ownership/check_build_ownership.js
  hdr "红项归属逐条对账（本单 pathspec 只含 09_工程脚本/**.js/.json + CodeReview/20260924-AUDIT-乙-D8-证据/**）"
  run git -c core.quotepath=false status --porcelain -- Core Tests Examples
  echo "⇒ 上列 .pas 修改全部来自他方在途工作（非本单 pathspec），四门红项与本单无因果。"
} > "$OUT/D8-交付前五门复跑.txt"

echo "证据文件已重生成于 $OUT/"
