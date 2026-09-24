# D7 段2 第二档/第三档修复：
#  A) 丙-C（双重编码）可逆还原：把每段非 ASCII 残块按 GBK 反向编码回字节再按 UTF-8 解码，
#     成功即得原文（数学可逆，逐处留痕）；U+20AC 特判为 cp936 单字节 0x80。
#  B) 第三档语义重写：按 (文件, 行号, 新文本) 映射整行替换，行号必须落在损坏行上（守卫），
#     否则报错不写。原文不可从仓库任何 revision 恢复，故只留 diff。
# 两档都保持 BOM 与 CRLF 原样。
import re
import sys

K = '锟斤拷'
F = ''
CYR = re.compile('[\u0400-\u04ff\u0590-\u05ff]')


def is_dirty(s):
    b = s.encode('utf-8')
    return bool(K in s or F in s
                or any(0x80 <= b[j] <= 0xff and b[j + 1] == 0x3F for j in range(len(b) - 1))
                or CYR.search(s))


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
    """对行内每个非 ASCII 连续段尝试可逆还原；只要有任一段成功就返回新行。"""
    parts, pos, changed = [], 0, False
    for m in re.finditer(r'[^\x00-\x7f]+', line):
        parts.append(line[pos:m.start()])
        fx = run_to_utf8(m.group(0))
        if fx is not None and fx != m.group(0):
            parts.append(fx)
            changed = True
        else:
            parts.append(m.group(0))
        pos = m.end()
    parts.append(line[pos:])
    return (''.join(parts) if changed else None)


def load(path):
    raw = open(path, 'rb').read()
    bom = raw.startswith(b'\xef\xbb\xbf')
    txt = raw.decode('utf-8-sig')
    eol = '\r\n' if '\r\n' in txt else '\n'
    return bom, eol, txt.split(eol)


def save(path, bom, eol, lines):
    data = eol.join(lines).encode('utf-8')
    if bom:
        data = b'\xef\xbb\xbf' + data
    open(path, 'wb').write(data)


log = []

# ---- A) 可逆还原（丙-C） ----------------------------------------------------
REVERSIBLE = {'doQry/doQryMain.pas': [112, 168, 176, 179, 180, 189, 191, 192, 193, 198]}
for path, nums in REVERSIBLE.items():
    bom, eol, lines = load(path)
    for n in nums:
        old = lines[n - 1]
        if is_dirty(old):
            log.append('SKIP-DIRTY %s:%d（属第三档，不在此处理）' % (path, n))
            continue
        new = decode_line(old)
        if new is None:
            log.append('NOT-REVERSIBLE %s:%d %r' % (path, n, old))
            continue
        lines[n - 1] = new
        log.append('REVERSIBLE %s:%d  %r -> %r' % (path, n, old, new))
    save(path, bom, eol, lines)

# ---- B) 第三档语义重写 ------------------------------------------------------
REWRITE = {'doQry/doQryMain.pas': '.tmp/d7/map_doQryMain.txt',
           'doQry/uDoQryLegacy.pas': '.tmp/d7/map_uDoQryLegacy.txt'}
LINEDIR = {'doQry/doQryMain.pas': [122, 129, 139, 142, 145, 146, 151, 153, 210, 214, 215, 218,
                                   237, 247, 251, 252, 267, 271, 277, 291, 297, 311, 317],
           'doQry/uDoQryLegacy.pas': [77, 128, 131, 201, 203, 207, 210, 214, 216, 219, 221, 225, 744]}
bad = 0
for path, mapfile in REWRITE.items():
    new_texts = [l.rstrip('\r\n') for l in open(mapfile, encoding='utf-8')]
    nums = LINEDIR[path]
    if len(new_texts) != len(nums):
        print('FATAL 映射行数 %d != 行号数 %d (%s)' % (len(new_texts), len(nums), path))
        sys.exit(2)
    bom, eol, lines = load(path)
    for n, nt in zip(nums, new_texts):
        old = lines[n - 1]
        if not is_dirty(old):
            log.append('GUARD-FAIL %s:%d 目标行不是损坏行，拒绝改写 %r' % (path, n, old))
            bad += 1
            continue
        for ch in ('\ufffd', '锟斤拷'):
            if ch in nt:
                log.append('GUARD-FAIL %s:%d 新文本仍含损坏字符' % (path, n))
                bad += 1
                nt = None
                break
        if nt is None:
            continue
        lines[n - 1] = nt
        log.append('REWRITE %s:%d  %r -> %r' % (path, n, old, nt))
    save(path, bom, eol, lines)

print('\n'.join(log))
print('---- 可逆还原/语义重写 完成，守卫失败 %d 处' % bad)
sys.exit(1 if bad else 0)
