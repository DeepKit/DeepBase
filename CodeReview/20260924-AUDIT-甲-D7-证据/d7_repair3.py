# D7 段2 第二档：丙-C（UTF-8 字节被当 GBK 读）可逆还原。
# 与 repair2 的差异：修正了 U+FFFD 字面量被工具链吞成空串导致的 is_dirty 恒真假阳性。
# 试算模式（默认）只打印不写盘；--apply 才写。
import re
import sys

REVERSIBLE = {'doQry/doQryMain.pas': [112, 168, 176, 179, 180, 189, 191, 192, 193, 198]}
FFFD = '\ufffd'
K = '锟斤拷'


def run_to_utf8(run):
    out = bytearray()
    for ch in run:
        if ch == '€':
            out += b'\x80'
            continue
        try:
            out += ch.encode('gb18030')
        except UnicodeEncodeError:
            return None
    try:
        return out.decode('utf-8')
    except UnicodeDecodeError:
        return None


def decode_line(line):
    parts, pos, changed, failed = [], 0, False, []
    for m in re.finditer(r'[^\x00-\x7f]+', line):
        parts.append(line[pos:m.start()])
        fx = run_to_utf8(m.group(0))
        if fx is not None and fx != m.group(0):
            parts.append(fx)
            changed = True
        else:
            parts.append(m.group(0))
            failed.append(m.group(0))
        pos = m.end()
    parts.append(line[pos:])
    return (''.join(parts) if changed else None), failed


def load(path):
    raw = open(path, 'rb').read()
    bom = raw.startswith(b'\xef\xbb\xbf')
    txt = raw.decode('utf-8-sig')
    return bom, '\r\n', txt.split('\r\n')


apply_changes = '--apply' in sys.argv
total = 0
for path, nums in REVERSIBLE.items():
    bom, eol, lines = load(path)
    for n in nums:
        old = lines[n - 1]
        assert FFFD not in old and K not in old, 'unexpected tier-3 marker at %s:%d' % (path, n)
        new, failed = decode_line(old)
        if new is None:
            print('NOT-REVERSIBLE %s:%d %r residual=%r' % (path, n, old, failed))
            total += 1
            continue
        print('REVERSIBLE %s:%d  %r -> %r  residual=%r' % (path, n, old, new, failed))
        lines[n - 1] = new
    if apply_changes:
        data = eol.join(lines).encode('utf-8')
        if bom:
            data = b'\xef\xbb\xbf' + data
        open(path, 'wb').write(data)
print('---- %s：不可还原 %d 处' % ('APPLY' if apply_changes else 'DRY-RUN', total))
