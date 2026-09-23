# -*- coding: utf-8 -*-
# 乙 D6 §2.2 落笔后核验：证明「本单全部改动 = 补回集，且只有补回集」。
#
# 基线用 47dc031（本单开工前最后一笔）的隔离工作树 .tmp/wt_d6_before，不用 `git show`：
# *.pas/*.dpr 在 .gitattributes 里是 `text eol=crlf`，blob 是 LF、工作树是 CRLF，
# 拿 blob 和工作树逐行比会把「行尾转换」误报成「内容改动」。工作树对工作树比才是同尺度。
#
# 本脚本刻意不复用 d6_line_repair.py 的行对齐：核验若与被核验对象共用同一套映射，
# 对齐错了也会一起错。这里改用与位置无关的判据（祖先【整行字节命中】+ 骨架【只增不减】
# + 命中位置【单调】），独立地回答「改动的每一行确实取自该干净祖先」。
#
# 五件必须同时成立，任一不成立即 EXIT=1：
#   A 逐行差异集 = 补回集（行数与 d6_line_repair.py 的 REPAIR 合计一致）
#   B 每个改动行的新值，逐字节等于干净祖先 blob 中的某一整行（改名行按机械改名后命中），
#     命中位置随行号单调递增；祖先与现场行数相同的件还要求命中位置就是原行号
#   C 文件级不变量：BOM 保留、行数不变、修后工作树 U+FFFD 归零、文件内行尾形态统一
#     （不在这里比较「修前 vs 修后 \\r 存在性」：修前基线是 47dc031 的隔离检出树，行尾由 checkout
#      按 eol=crlf 生成；本仓共享工作树里另有一批从未触碰的件本身就是 w/lf（见
#      判据C-工作树行尾形态.txt），跨树比 \\r 会把检出形态误报成本单改动。仓库侧 blob 恒为 LF，
#      `text` 属性下工作树 \\r 差异对 git 不可见，故另以「文件内形态统一」自证未混入混合行尾）
#   D 每个改动行只补不删：sk(修前) ⊆ sk(修后)（改动没有删掉修前已有的任何 ASCII）。
#     再按「恢复了 ASCII（引号被吞那类）」/「只修正非 ASCII（649b1e07 造成的乱码正字化）」分档统计，
#     后者是同一祖先原文的正常补回，不判失败。
#   E 隔离基线树内容 == 47dc031 的 blob 内容（modulo \r），防止基线树被他人改动污染
# 用法（必须在仓库根跑）：python CodeReview/.../d6_verify_after.py > 证据.txt
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8')

BOM = b'\xef\xbb\xbf'
CR = b'\r'
PRE = '47dc031'          # 本单开工前最后一笔（甲 D5 交付回执）
BEFORE = '.tmp/wt_d6_before'
RENAME = (b'UniBase', b'DeepBase')
# (件, 该件最后一个编码干净祖先, d6_line_repair.py 报告的 REPAIR 行数)
CASES = [('Examples/MultiLanguageDemo/MainForm.pas', '7516962d', 18),
         ('Tests/Acceptance/AcceptanceRunner.pas', '42664177', 89),
         ('Tools/LogAnalyzer/LogAnalyzer.MainForm.pas', '69d3f66c', 97),
         ('Tests/TestLLMClient.dpr', 'ccfc338b', 23),
         ('Tests/Acceptance/AcceptanceMain.pas', '42664177', 30),
         ('Tools/LogAnalyzer/LogAnalyzer.dpr', '69d3f66c', 3),
         # 首错遮蔽：上一件修完后编译器才走到这一件
         ('Tests/Acceptance/AcceptanceReport.pas', '42664177', 35)]


def blob(rev, path):
    r = subprocess.run(['git', 'show', '%s:%s' % (rev, path)], capture_output=True)
    if r.returncode != 0:
        sys.exit('git show 失败 %s:%s' % (rev, path))
    return r.stdout


def file_lines(path):
    with open(path, 'rb') as fh:
        raw = fh.read()
    return raw, (raw[len(BOM):] if raw.startswith(BOM) else raw).split(b'\n')


def split_blob(raw):
    return (raw[len(BOM):] if raw.startswith(BOM) else raw).split(b'\n')


def content(line):
    return line.rstrip(CR)


def sk(raw):
    return ''.join(chr(b) for b in raw if b < 0x80 and b != 0x3F)


def subseq(needle, hay):
    it = iter(hay)
    return all(c in it for c in needle)


fail = 0
for path, base, n_repair in CASES:
    b_raw, H = file_lines('%s/%s' % (BEFORE, path))
    c_raw, Cu = file_lines(path)
    A = [content(x) for x in split_blob(blob(base, path))]
    H = [content(x) for x in H]
    print('##### %s   依据祖先 %s' % (path, base))
    print('  C 文件级：行数 修前=%d 修后=%d | BOM %s→%s | U+FFFD 修前=%d 修后=%d | CRLF 修前=%d 修后=%d' % (
        len(H), len(Cu),
        '有' if b_raw.startswith(BOM) else '无', '有' if c_raw.startswith(BOM) else '无',
        b_raw.count(b'\xef\xbf\xbd'), c_raw.count(b'\xef\xbf\xbd'),
        b_raw.count(b'\r\n'), c_raw.count(b'\r\n')))
    if len(H) != len(Cu):
        print('  !! 修前/修后行数不等，无法逐行对齐'); fail += 1; continue
    if b_raw.startswith(BOM) != c_raw.startswith(BOM):
        print('  !! BOM 漂移'); fail += 1
    if c_raw.count(b'\xef\xbf\xbd') != 0:
        print('  !! 修后工作树 U+FFFD 未归零'); fail += 1
    crs = [i for i, l in enumerate(Cu[:-1]) if l.endswith(CR)]
    if crs and len(crs) != len(Cu) - 1:
        print('  !! 修后文件内行尾形态不统一（CRLF %d / 内容行 %d），本单不得引入混合行尾' % (len(crs), len(Cu) - 1)); fail += 1
    if [content(x) for x in split_blob(blob(PRE, path))] != H:
        print('  !! 隔离基线树与 %s 的 blob 内容不一致（E）' % PRE); fail += 1

    diff = [i for i in range(len(H)) if H[i] != content(Cu[i])]
    bad_value, lost_ascii, pos_off = [], [], []
    ascii_back, mojibake_only = 0, 0
    prev_j = -1
    for i in diff:
        v = content(Cu[i])
        # B：整行字节命中祖先行（原样，或按 ca3364ee 那次机械改名后），且命中位置单调递增
        js = [j for j in range(prev_j + 1, len(A)) if A[j] == v or A[j].replace(*RENAME) == v]
        if not js:
            bad_value.append(i + 1)
        else:
            prev_j = js[0]
            if len(A) == len(Cu) and prev_j != i:
                pos_off.append(i + 1)
        # D：改动只补不删（修前骨架是修后骨架的子集），并按是否恢复 ASCII 分档
        if not subseq(sk(H[i]), sk(v)):
            lost_ascii.append(i + 1)
        elif sk(H[i]) == sk(v):
            mojibake_only += 1
        else:
            ascii_back += 1
    print('  A 逐行差异行数 = %d（d6_line_repair.py 报告 REPAIR=%d）%s' %
          (len(diff), n_repair, '一致' if len(diff) == n_repair else '不一致'))
    print('  B 新值在祖先 blob 中找不到整行命中的行数 = %d %s' % (len(bad_value), bad_value[:8]))
    print('  B 行数相同的件里命中位置 != 原行号的行数 = %d %s' % (len(pos_off), pos_off[:8]))
    print('  D 只补不删：恢复 ASCII 的行数 = %d / 仅修正非 ASCII（乱码→正字）的行数 = %d' % (ascii_back, mojibake_only))
    print('  D 改动删掉了修前已有 ASCII 的行数 = %d %s' % (len(lost_ascii), lost_ascii[:8]))
    if len(diff) != n_repair or bad_value or pos_off or lost_ascii:
        fail += 1
    print('  改动行号（前 12）= %s' % [i + 1 for i in diff][:12])

print('=' * 70)
print('VERIFY_%s (fail=%d)' % ('OK' if fail == 0 else 'FAIL', fail))
sys.exit(0 if fail == 0 else 1)
