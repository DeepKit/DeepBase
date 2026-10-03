# -*- coding: utf-8 -*-
"""F10 行号漂移核定：定位 HEAD 文件中嵌入的 unicode 行分隔符，并对比两种切分编号。"""
import io, sys

PATH = 'Examples/Templates/Common/Template.AutoUpdateBootstrap.pas'
data = open(PATH, 'rb').read()
text = data.decode('utf-8')  # BOM 保留为

print('=== 1) 特殊行分隔符计数 ===')
for name, cp in [('NEL U+0085', 0x85), ('LS  U+2028', 0x2028), ('PS  U+2029', 0x2029), ('VT  U+000B', 0x0B), ('FF  U+000C', 0x0C)]:
    print('  %s = %d' % (name, text.count(chr(cp))))
print('  CR   = %d' % text.count('\r'))

print()
print('=== 2) 两种切分的行数 ===')
nl = text.split('\n')
ul = text.splitlines()
print('  split("\\n")   -> %d 行' % len(nl))
print('  splitlines()  -> %d 行' % len(ul))

print()
print('=== 3) splitlines() 前 10 行（Read 工具编号口径）===')
for i, l in enumerate(ul[:10], 1):
    print('  R%-3d %s' % (i, repr(l[:75])))

print()
print('=== 4) split("\\n") 前 10 行（原始字节行口径）===')
for i, l in enumerate(nl[:10], 1):
    print('  N%-3d %s' % (i, repr(l[:75])))

print()
print('=== 5) 嵌入 unicode 换行符的位置与上下文 ===')
for i, ch in enumerate(text):
    if ch in ('\x85', '\u2028', '\u2029'):
        print('  offset %d  U+%04X  上文: %s' % (i, ord(ch), repr(text[max(0, i-30):i+30])))

print()
print('=== 6) 两套编号的对应关系（前 12 行）===')
# 找出每个 splitlines 行对应的 \n 行号
n_idx = 1
pos = 0
for r_idx, line in enumerate(ul, 1):
    if r_idx > 12:
        break
    # 计算该 splitlines 行结束处在 \n 切分中的行号
    start = pos
    pos += len(line)
    nl_no = text.count('\n', 0, start) + 1
    print('  R%-3d -> N%-3d  %s' % (r_idx, nl_no, repr(line[:60])))

print()
print('=== 7) 乱码行判定（两套编号各自列出） ===')
MOJI = set('涓轰簡妯')
def moji_lines(lines, label):
    hits = []
    for i, l in enumerate(lines, 1):
        if any(c in MOJI for c in l):
            hits.append(i)
    print('  %s 编号下含乱码特征字的行: %s （共 %d 行）' % (label, hits, len(hits)))
    for i in hits:
        print('    %s%d: %s' % (label, i, repr(lines[i-1][:75])))
moji_lines(nl, 'N')
moji_lines(ul, 'R')
