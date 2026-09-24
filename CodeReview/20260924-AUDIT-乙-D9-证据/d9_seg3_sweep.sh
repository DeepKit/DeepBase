#!/usr/bin/env bash
# D9 段3 复扫：对「git status 显示为脏的已跟踪文件」逐件做字节级判定，
# 区分 假脏（入库后内容与 HEAD 完全一致，M 只来自行尾表示 + 索引 stat）与 真差异（他人/本单的实际内容改动）。
# 为什么文件清单取自 status 而不是 diff：diff 会应用 clean filter，假脏件根本不进 diff 列表，
# 用 diff 当清单会得出"假脏=0"的假 PASS；判据 3 的口径本身就是 status --porcelain 的已跟踪条目。
#   raw      = git hash-object --no-filters -> 磁盘原始字节（含 CRLF）
#   filtered = git hash-object               -> 过 clean filter（行尾归一）后的 blob，即"入库后"的字节
#   idx/HEAD = 索引 / HEAD 中的 blob
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 1

printf '执行时刻 = %s\n' "$(date -Is)"
printf '基准 HEAD = %s\n' "$(git rev-parse HEAD)"
printf '落笔前 staged（git diff --cached --name-only）= %s\n\n' "$(git diff --cached --name-only | tr '\n' ' ')"

printf '%-10s %-4s %-9s %-9s %-10s %-8s %s\n' 判定 status 'flt==HEAD' 'flt==idx' numstat 归属 文件
fake=0; real=0; deleted=0
# 本单申报清单（其余已跟踪脏件一律标 他方，用于零夹带自证）
is_mine() {
  case "$1" in
    README.md | .gitignore | docs/规范历史版本与对比库/*) return 0 ;;
    *) return 1 ;;
  esac
}
# status --porcelain 取「已跟踪且脏」条目：排除 ?? ，取第 1、2 列作 XY 状态
git -c core.quotepath=false status --porcelain | grep -v '^??' | cut -c 4- | while IFS= read -r f; do
  st=$(git -c core.quotepath=false status --porcelain -- "$f" | cut -c 1-2)
  head=$(git rev-parse "HEAD:$f" 2>/dev/null)
  owner=$(is_mine "$f" && echo 本单 || echo 他方)
  if [ ! -f "$f" ]; then
    printf '%-10s %-4s %-9s %-9s %-10s %-8s %s\n' 删除 "$st" - - - "$owner" "$f"
    deleted=$((deleted + 1)); continue
  fi
  idx=$(git rev-parse ":$f" 2>/dev/null)
  flt=$(git hash-object -- "$f" 2>/dev/null)
  ns=$(git diff --numstat HEAD -- "$f" | awk '{print $1"+/" $2"-"}'); [ -n "$ns" ] || ns='none'
  if [ "$flt" = "$head" ]; then
    v=假脏; fake=$((fake + 1))
  else
    v=真差异; real=$((real + 1))
  fi
  printf '%-10s %-4s %-9s %-9s %-10s %-8s %s\n' "$v" "$st" \
    "$([ "$flt" = "$head" ] && echo Y || echo N)" \
    "$([ "$flt" = "$idx" ] && echo Y || echo N)" "$ns" "$owner" "$f"
done

printf '\n假脏件数 = %s\n' "$(git -c core.quotepath=false status --porcelain | grep -v '^??' | cut -c 4- | while IFS= read -r f; do [ -f "$f" ] || continue; [ "$(git hash-object -- "$f")" = "$(git rev-parse "HEAD:$f")" ] && echo x; done | wc -l | tr -d ' ')"
printf '已跟踪脏条目总数（判据3分母）= %s\n' "$(git -c core.quotepath=false status --porcelain | grep -vc '^??')"
printf '其中属本单申报清单 = %s\n' "$(git -c core.quotepath=false status --porcelain | grep -v '^??' | cut -c 4- | grep -cE '^README\.md$|^\.gitignore$|^docs/规范历史版本与对比库/')"
