# -*- coding: utf-8 -*-
# 乙 D6 §2.1/§2.2：「有损编码吞引号」逐行定位与按依据补回。
#
# 三方对照（每行）：
#   B = base  最后一个编码干净祖先（本单逐件实测 ?=0 U+FFFD=0）
#   M = mid   ca3364ee（UniBase→DeepBase 改名提交，实测本单各件的引号就是这一笔吞掉的）
#   C = cur   工作树（甲 D3/D6 编译门照出 E2052 的现场）
# 补回值 = B 行 + 机械改名（UniBase→DeepBase），因为 ca3364ee 除了改名与编码损坏之外没有别的合法编辑。
# 这个前提由下面两条骨架判据机器将验，任一条不过即归 MISMATCH 交人工，绝不自动落笔：
#   sk(x) = x 去掉非 ASCII 字节与 `?`（有损掩码位）后的 ASCII 骨架
#   1) sk(M) ⊆ sk(B')   —— mid 相对 base 只少了被编码损坏吃掉的 ASCII，没有新增内容
#   2) sk(C) ⊆ sk(B')   —— 工作树同理（B' = base 行改名后）
#
# B 与 C 的行对应关系不靠行号（AcceptanceMain.pas 相对祖先有一处合法增行造成的整体位移），
# 由 align_map 的对齐块推出；对不齐的行一律不映射、不落笔。
# 用法：python d6_line_repair.py [--apply] [--root <目录>]
#   --root 只用于把「工作树现场」换成别处的树（如修前隔离树）做重跑对照；不带 --apply 时一律不写。
import difflib
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8')

MID = 'ca3364ee'
BOM = b'\xef\xbb\xbf'
RENAME = ('UniBase', 'DeepBase')
# (件, 编译门首个 E2052 行, 该件最后一个编码干净祖先)
CASES = [('Examples/MultiLanguageDemo/MainForm.pas', 119, '7516962d'),
         ('Tests/Acceptance/AcceptanceRunner.pas', 158, '42664177'),
         ('Tools/LogAnalyzer/LogAnalyzer.MainForm.pas', 186, '69d3f66c'),
         ('Tests/TestLLMClient.dpr', 35, 'ccfc338b'),
         # 修完上面四件的首个报错行后，同一编译单元内后面还有同类损坏，编译门随即照出下一处：
         ('Tests/Acceptance/AcceptanceMain.pas', 77, '42664177'),
         ('Tools/LogAnalyzer/LogAnalyzer.dpr', 28, '69d3f66c'),
         # 编译门逐层暴露：AcceptanceMain.pas 修好后同一工程的下一个 E2052 才可见（首错遮蔽）
         ('Tests/Acceptance/AcceptanceReport.pas', 49, '42664177')]


def git_lines(rev, path):
    r = subprocess.run(['git', 'show', '%s:%s' % (rev, path)], capture_output=True)
    if r.returncode != 0:
        sys.exit('git show 失败 %s:%s' % (rev, path))
    raw = r.stdout
    if raw.startswith(BOM):
        raw = raw[len(BOM):]
    return raw.split(b'\n')


def read_lines(path):
    """逐行取工作树字节，并把 UTF-8 BOM 单独摘出来：BOM 属于文件而非首行内容，
    补回首行时若把 BOM 当行内容一起换掉就会静默丢 BOM（G3 会红）。"""
    with open(path, 'rb') as fh:
        raw = fh.read()
    bom = raw.startswith(BOM)
    return (raw[len(BOM):] if bom else raw).split(b'\n'), bom


def sk(raw):
    return ''.join(chr(b) for b in raw if b < 0x80 and b != 0x3F)


def align_key(raw):
    # 本类损坏正是「吞掉闭引号」，骨架里少了个 `'` 会让序列比对把受损行误判成增删行，
    # 所以对齐键再去掉引号；这只影响行的对应关系，能不能落笔仍由 sk 的严格判据决定。
    # 祖先 blob 是 LF、工作树是 CRLF（.gitattributes 的 text eol=crlf），行尾 \\r 必须一并去掉，
    # 否则每一行的键都不相等，整文件对齐会直接崩掉。
    return sk(raw.replace(b'\r', b'')).replace("'", '')


def align_map(anc, cur):
    """返回 (cur 行号 -> anc 行号 的映射, 未映射 residue 块)。
    只接受 1:1 的 equal/replace 块；块长不等（合法增删行）内的行不映射。"""
    ka = [align_key(x) for x in anc]
    kc = [align_key(x) for x in cur]
    m = [None] * len(kc)
    residue = []
    sm = difflib.SequenceMatcher(None, ka, kc, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == 'equal' or (tag == 'replace' and (i2 - i1) == (j2 - j1)):
            for k in range(j2 - j1):
                m[j1 + k] = i1 + k
        else:
            residue.append((tag, i1 + 1, i2, j1 + 1, j2))
    return m, residue


def subseq(needle, hay):
    it = iter(hay)
    return all(c in it for c in needle)


def marker_count(raw):
    s = raw.decode('utf-8', 'replace')
    return s.count('\ufffd'), s.count('?')


def show(tag, raw):
    print('    %-8s| %s' % (tag, raw.decode('utf-8', 'replace')))


def arg(name):
    for i, a in enumerate(sys.argv):
        if a.startswith(name + '='):
            return a.split('=', 1)[1]
        if a == name and i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


APPLY = '--apply' in sys.argv
ROOT = arg('--root') or '.'
tot = {'SAME': 0, 'REPAIR': 0, 'MISMATCH': 0, 'UNMAPPED': 0}
# REPAIR 行的来源分档：DAMAGE_ONLY = 工作树自 ca3364ee 起未再改动，差异全部由该笔编码损坏解释；
# AFTERMATH_EDIT = 工作树在 ca3364ee 之后还动过这一行，需人工确认后续改动是否只落在受损字节上。
src_tot = {'DAMAGE_ONLY': 0, 'AFTERMATH_EDIT': 0}
for path, err_line, base in CASES:
    cur_path = os.path.join(ROOT, path)
    B, M, (C, has_bom) = git_lines(base, path), git_lines(MID, path), read_lines(cur_path)
    print('=' * 78)
    print('##### %s   编译门首个报错行 L%d   现场=%s   工作树 BOM=%s' % (path, err_line, ROOT, '有' if has_bom else '无'))
    if len(M) != len(C):
        print('  !! cur 与 mid 行数不等 mid=%d cur=%d —— 本件整体交人工' % (len(M), len(C)))
        continue
    m_map, residue = align_map(B, C)
    print('  对齐：cur=%d 行，祖先=%d 行，未映射块=%s' %
          (len(C), len(B), residue if residue else '无（行行对应）'))
    bf, bm = marker_count(b'\n'.join(B))
    print('  base %s 标记计数 U+FFFD=%d `?`=%d（=> 该祖先编码干净，可作补回依据）' % (base, bf, bm))
    stat = {'SAME': 0, 'REPAIR': 0, 'MISMATCH': 0, 'UNMAPPED': 0}
    stat_src = {'DAMAGE_ONLY': 0, 'AFTERMATH_EDIT': 0}
    new = list(C)
    for i in range(len(C)):
        c, m = C[i], M[i]
        j = m_map[i]
        cr, mr = c.rstrip(b'\r'), m.rstrip(b'\r')
        if j is None:
            stat['UNMAPPED'] += 1
            print('  L%d UNMAPPED（祖先侧无可对应的 1:1 行——合法增删行，本行不动）' % (i + 1))
            show('mid', mr)
            show('cur', cr)
            continue
        br = B[j].rstrip(b'\r')
        cand = br
        if RENAME[0].encode() in cand and RENAME[1].encode() in mr:
            cand = cand.replace(*[s.encode() for s in RENAME])
        if cr == cand:
            stat['SAME'] += 1
            continue
        ok = subseq(sk(mr), sk(cand)) and subseq(sk(cr), sk(cand))
        if not ok:
            stat['MISMATCH'] += 1
            print('  L%d MISMATCH（骨架判据不过，禁止自动取祖先）' % (i + 1))
            show('base', br)
            show('mid', mr)
            show('cur', cr)
            continue
        stat['REPAIR'] += 1
        src = 'DAMAGE_ONLY' if cr == mr else 'AFTERMATH_EDIT'
        stat_src[src] += 1
        src_tot[src] += 1
        new[i] = cand + (b'\r' if c.endswith(b'\r') and not cand.endswith(b'\r') else b'')
        print('  L%d REPAIR [%s]（祖先 L%d）' % (i + 1, src, j + 1))
        show('补回前', cr)
        show('补回后', cand)
        if src == 'AFTERMATH_EDIT':
            show('mid(ca3364ee)', mr)
            print('    骨架 cur | %s' % sk(cr))
            print('    骨架 补回 | %s' % sk(cand))
        print('    依据    | %s(该祖先此文件 U+FFFD=0 且 `?`=0) 该行原文%s' % (base, '；' + ' + 机械改名 %s→%s' % RENAME if cand != br else ''))
    for k in ('SAME', 'REPAIR', 'MISMATCH', 'UNMAPPED'):
        print('  %-9s %d' % (k, stat[k]))
        tot[k] += stat[k]
    print('  REPAIR 来源分档 DAMAGE_ONLY=%d AFTERMATH_EDIT=%d' % (stat_src['DAMAGE_ONLY'], stat_src['AFTERMATH_EDIT']))
    if stat['MISMATCH'] == 0 and stat['REPAIR'] > 0 and APPLY and ROOT == '.':
        blob = BOM + b'\n'.join(new) if has_bom else b'\n'.join(new)
        with open(cur_path, 'wb') as fh:
            fh.write(blob)
        ff, qm = marker_count(blob)
        print('  => 已写入（%d 行补回，其余 %d 行字节不动）；写后自检 BOM=%s U+FFFD=%d' %
              (stat['REPAIR'], len(C) - stat['REPAIR'], '保' if blob.startswith(BOM) else '丢', ff))
    elif stat['MISMATCH'] == 0:
        print('  => dry-run（未写入）')
    else:
        print('  => 存在 %d 行 MISMATCH，本件不写入，先人工处理' % stat['MISMATCH'])

print('=' * 78)
print('合计  SAME=%(SAME)d REPAIR=%(REPAIR)d MISMATCH=%(MISMATCH)d UNMAPPED=%(UNMAPPED)d' % tot)
print('合计  REPAIR 来源分档 DAMAGE_ONLY=%(DAMAGE_ONLY)d AFTERMATH_EDIT=%(AFTERMATH_EDIT)d' % src_tot)
