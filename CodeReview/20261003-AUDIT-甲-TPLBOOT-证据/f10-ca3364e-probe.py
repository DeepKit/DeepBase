# -*- coding: utf-8 -*-
"""ca3364e 版本逐字节判定 + blob 一致性校验。"""
import subprocess

P = 'CodeReview/20261003-AUDIT-甲-TPLBOOT-证据/ca3364e-Template.AutoUpdateBootstrap.pas'
raw = open(P, 'rb').read()

blob = 'ca3364e:Examples/Templates/Common/Template.AutoUpdateBootstrap.pas'
h1 = subprocess.run(['git', 'rev-parse', blob], capture_output=True, text=True).stdout.strip()
h2 = subprocess.run(['git', 'hash-object', P], capture_output=True, text=True).stdout.strip()
print('blob sha (git rev-parse) =', h1)
print('sha of saved copy        =', h2)
print('一致性:', h1 == h2)

print()
print('=== 损坏点上下文 (utf-8 replace) ===')
t = raw.decode('utf-8', errors='replace')
# 用字节级扫描找出所有非 utf-8 位置
import codecs
dec = codecs.getincrementaldecoder('utf-8')('replace')
bad_bytes = []
pos = 0
while pos < len(raw):
    try:
        raw[pos:pos+1].decode('utf-8')
        pos += 1
    except UnicodeDecodeError:
        bad_bytes.append(pos)
        pos += 1
# 更可靠: 用 errors=replace 对比长度差
enc = raw.decode('utf-8', errors='replace')
print('replace 解码后长度 =', len(enc), '文件字节长 =', len(raw))
idx = 0
for i, ch in enumerate(enc):
    if ch == '�':
        print('  U+FFFD at char %d, 上下文: %s' % (i, repr(enc[max(0,i-20):i+20])))

print()
print('=== 前 200 字节 hex ===')
print(raw[:200].hex(' '))
print()
print('=== GBK 试解码 ===')
try:
    g = raw.decode('gbk')
    print('gbk 解码成功, 前 80 字符:')
    print(repr(g[:80]))
except UnicodeDecodeError as e:
    print('gbk 失败:', e)
