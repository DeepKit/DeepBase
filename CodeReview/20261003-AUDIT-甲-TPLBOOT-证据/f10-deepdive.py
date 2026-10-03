# -*- coding: utf-8 -*-
"""深挖 1：HEAD 文件 N5 全文本 + 全部控制字符扫描；深挖 2：ca3364e 编码判定。"""
import sys

print('=== A) HEAD 文件控制字符全扫描 (0x00-0x1F) ===')
data = open('Examples/Templates/Common/Template.AutoUpdateBootstrap.pas', 'rb').read()
text = data.decode('utf-8')
for b in range(0x20):
    c = text.count(chr(b))
    if c:
        print('  U+%04X count=%d' % (b, c))
print('  U+FFF6..U+FFFF 区:')
for b in range(0xFFF0, 0x10000):
    if text.count(chr(b)):
        print('    U+%04X count=%d' % (b, text.count(chr(b))))

print()
print('=== B) HEAD N5 全文本 ===')
nl = text.split('\n')
print(repr(nl[4]))

print()
print('=== C) N5 中 onExit/staged/下载 的位置 ===')
for kw in ['onExit', 'staged', '下载', '后台轮询安装窗口', '策略化静默更新编排']:
    print('  %-16s in N5: %s' % (kw, kw in nl[4]))

print()
print('=== D) ca3364e 版本编码判定 ===')
raw = open('CodeReview/20261003-AUDIT-甲-TPLBOOT-证据/ca3364e-Template.AutoUpdateBootstrap.pas', 'rb').read()
print('  长度 =', len(raw))
print('  前 8 字节 hex =', raw[:8].hex(' '))
for enc in ('utf-8', 'gbk', 'utf-16'):
    try:
        t = raw.decode(enc)
        print('  %-6s 解码成功, len=%d, 前60=%s' % (enc, len(t), repr(t[:60])))
    except UnicodeDecodeError as e:
        print('  %-6s 失败: %s' % (enc, str(e)[:80]))
try:
    t = raw.decode('utf-8', errors='replace')
    bad = [i for i, ch in enumerate(t) if ch == '�']
    print('  utf-8(replace) 损坏位置数=%d, 前5=%s' % (len(bad), bad[:5]))
except Exception as e:
    print('  replace 也炸:', e)
