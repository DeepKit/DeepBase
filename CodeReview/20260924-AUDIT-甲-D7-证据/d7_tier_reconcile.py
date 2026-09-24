# D7 段2 三档留痕对账（零硬编码：所有数字由本脚本现算，禁止手打）。
# 改前基线 = .tmp/d7_a_base/doQry/*（@a3e3f38 隔离工作树副本）；
# 留痕位点 = 档1 d7_restore_log.txt 的 RESTORE 行 / 档2 d7_repair3.py 的 REVERSIBLE / 档3 d7_repair2.py 的 LINEDIR
# （两个修复脚本用 ast 抽字面量，绝不 import，否则会重跑写盘逻辑）。
import ast
import os
import re
import sys

FFFD = '\ufffd'
K = '锟斤拷'
CODE_EXT = ('.pas', '.dpr', '.dpk', '.dfm', '.dproj', '.inc')
CYR = re.compile('[\u0400-\u04ff\u0590-\u05ff\u0700-\u074f\u0180-\u024f]')
CYR_NARROW = re.compile('[\u0400-\u04ff]')
BASE = '.tmp/d7_a_base'
LOG = '.tmp/d7/d7_restore_log.txt'


def tags(line):
    b = line.encode('utf-8')
    t = []
    if any(0x80 <= b[j] <= 0xff and b[j + 1] == 0x3F for j in range(len(b) - 1)):
        t.append('A')
    if FFFD in line:
        t.append('B')
    if K in line:
        t.append('D')
    if CYR.search(line):
        t.append('E')
    return t


def literal(path, name):
    tree = ast.parse(open(path, encoding='utf-8').read())
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign):
            for tgt in node.targets:
                if isinstance(tgt, ast.Name) and tgt.id == name:
                    return ast.literal_eval(node.value)
    raise SystemExit('FATAL %s 中找不到 %s' % (path, name))


before = {}
wide_narrowE = set()
narrow_a = narrow_b = 0
narrow_unique = set()
for dirpath, dirs, files in os.walk(os.path.join(BASE, 'doQry')):
    dirs[:] = [d for d in dirs if d not in ('.git', '__history', 'bin', 'dcu', 'log', 'Logs', 'output')]
    for fn in sorted(files):
        p = os.path.join(dirpath, fn)
        rel = os.path.relpath(p, BASE).replace('\\', '/')
        if not fn.lower().endswith(CODE_EXT):
            continue
        try:
            txt = open(p, 'rb').read().decode('utf-8-sig')
        except UnicodeDecodeError:
            print('FATAL 改前基线 %s 不是合法 UTF-8，探测口径失效' % rel)
            sys.exit(2)
        hit = {}
        for i, line in enumerate(txt.split('\n'), 1):
            tg = tags(line)
            if tg:
                hit[i] = tg
                if 'A' in tg or 'B' in tg or 'D' in tg or CYR_NARROW.search(line):
                    wide_narrowE.add((rel, i))
            if 'A' in tg:
                narrow_a += 1
                narrow_unique.add((rel, i))
            if 'B' in tg:
                narrow_b += 1
                narrow_unique.add((rel, i))
        if hit:
            before[rel] = sorted(hit)
            print('%s 宽口径损坏行=%d %s' % (rel, len(hit), dict((n, ''.join(t)) for n, t in sorted(hit.items()))))

TIER1 = {}
for m in re.finditer(r'^RESTORE (\S+?):(\d+) ', open(LOG, encoding='utf-8').read(), re.M):
    TIER1.setdefault(m.group(1), []).append(int(m.group(2)))
TIER2 = literal('.tmp/d7/d7_repair3.py', 'REVERSIBLE')
TIER3 = literal('.tmp/d7/d7_repair2.py', 'LINEDIR')
labels = [('档1-祖先法精确回补', TIER1), ('档2-丙-C-gb18030可逆还原', TIER2), ('档3-语义重写', TIER3)]

tally, unaccounted, multi = {}, [], []
for path, nums in sorted(before.items()):
    for n in nums:
        hit = [lab for lab, tbl in labels if n in tbl.get(path, [])]
        if len(hit) > 1:
            multi.append('%s:%d %s' % (path, n, hit))
        key = hit[0] if hit else '未留痕'
        tally[key] = tally.get(key, 0) + 1
        if not hit:
            unaccounted.append('%s:%d' % (path, n))

covered = set()
for _, tbl in labels:
    for path, nums in tbl.items():
        for n in nums:
            covered.add((path, n))
extra = sorted('%s:%d' % (p, n) for p, n in covered if n not in before.get(p, []))

print('---- 改前代码面损坏行(宽口径 A/B/D/E)=%d 其中D6窄E口径=%d' % (sum(len(v) for v in before.values()), len(wide_narrowE)))
print('---- 窄口径 丙-A行=%d 丙-B行=%d 唯一损坏行(A∪B)=%d' % (narrow_a, narrow_b, len(narrow_unique)))
print('---- 档1位点=%d 档2位点=%d 档3位点=%d' % (sum(len(v) for v in TIER1.values()),
      sum(len(v) for v in TIER2.values()), sum(len(v) for v in TIER3.values())))
print('---- 宽口径行按档分布 = %s' % tally)
print('---- 多档重复命中=%d %s' % (len(multi), multi))
print('---- 未留痕位点=%d %s' % (len(unaccounted), unaccounted))
print('---- 留痕超出改前探测的位点=%d %s' % (len(extra), extra))
sys.exit(1 if unaccounted else 0)
