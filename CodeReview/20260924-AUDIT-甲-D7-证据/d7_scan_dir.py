# D7 段2 全目录口径复扫：doQry 下所有文本文件的五类损坏行（代码面/文档面分列）。
import os
import re
import sys

FFFD = '\ufffd'
K = '锟斤拷'
CODE_EXT = ('.pas', '.dpr', '.dpk', '.dfm', '.dproj', '.inc')


def damaged(line):
    b = line.encode('utf-8')
    tags = []
    if any(0x80 <= b[j] <= 0xff and b[j + 1] == 0x3F for j in range(len(b) - 1)):
        tags.append('A')
    if FFFD in line:
        tags.append('B')
    if K in line:
        tags.append('D')
    if re.search('[\u0400-\u04ff]', line):
        tags.append('E')
    return tags


root = sys.argv[1]
code = doc = 0
for dirpath, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in ('.git', '__history', 'bin', 'dcu', 'log', 'Logs', 'output')]
    for fn in sorted(files):
        p = os.path.join(dirpath, fn)
        try:
            txt = open(p, 'rb').read().decode('utf-8-sig')
        except UnicodeDecodeError:
            continue
        hits = [(i, damaged(l)) for i, l in enumerate(txt.split('\n'), 1) if damaged(l)]
        if not hits:
            continue
        iscode = fn.lower().endswith(CODE_EXT)
        if iscode:
            code += len(hits)
        else:
            doc += len(hits)
        print('%-6s %s 行数=%d 损坏=%d %s' % ('CODE' if iscode else 'DOC', p.replace('\\', '/'), len(hits), len(hits), hits))
print('---- %s 全目录：代码面损坏行=%d 文档面损坏行=%d' % (root, code, doc))
