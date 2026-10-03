#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# WO-20261003-MC-甲-ORPHANREG 判据7: append-only batch merge into Tests/DeepBaseTests.dpr.
#
# Rules enforced by this script (work order 授权面):
#   * APPEND ONLY - new lines are inserted directly after the last existing Test.Regression.*
#     registration; no existing line is deleted, renamed or reordered (asserted before write).
#   * idempotent - re-running the same batch is a no-op (guards against double-run).
#   * CRLF + BOM preserved, no mojibake introduced (pure ASCII added lines).
#
# usage: merge-batch.py <batch-json-name>
import io, json, os, sys

ROOT = r'D:\_ProgData\DeepBase-ORPHANREG\wt-orphanreg'
DPR = os.path.join(ROOT, 'Tests', 'DeepBaseTests.dpr')
ANCHOR_PREFIX = '  Test.Regression.'
CRLF = chr(13) + chr(10)

BATCHES = {
    'batch1': ('WO-20261003-MC-甲-ORPHANREG batch1: signature + crypto primitives (6)',
               ['BUG013_RSASignature', 'BUG014_WeChatPaySignature', 'BUG033_WeakEncryption',
                'BUG035_InsecureRandom', 'BUG037_KeyDerivation', 'BUG058_XOREncryption']),
    'batch2': ('WO-20261003-MC-甲-ORPHANREG batch2: security posture + in-flight gate (6)',
               ['A8_InFlightUnloadGate', 'BUG062_PluginSandbox', 'BUG063_PluginConfigBypass',
                'BUG066_PathTraversal', 'BUG070_LogInjection', 'BUG073_EventTypeInjection']),
    'batch3': ('WO-20261003-MC-甲-ORPHANREG batch3: concurrency + serialization + visual (7)',
               ['BUG001_AnimationMemoryLeak', 'BUG009_LoggingRace', 'BUG010_WorkerQueueRace',
                'BUG054_SemaphoreLeak', 'BUG059_JsonDeserializationType',
                'BUG060_SerializationDepth', 'CR606_FrameDifferAlpha']),
}


def main():
    name = sys.argv[1]
    if name not in BATCHES:
        print('unknown batch', name)
        return 2
    label, units = BATCHES[name]
    raw = io.open(DPR, 'rb').read()
    # Tests/DeepBaseTests.dpr is pure ASCII WITHOUT a BOM; keep it that way (encoding gate G1..G6).
    assert raw[:3] != b'\xef\xbb\xbf', 'dpr unexpectedly carries a BOM - re-check gate expectations'
    assert raw.count(b'\n') == raw.count(b'\r\n'), 'dpr must stay CRLF-only'
    text = raw.decode('utf-8')  # UTF-8 without BOM (has Chinese comments)
    lines = text.split(CRLF)
    # anchor = last existing Test.Regression.* registration line
    anchor = -1
    for i, l in enumerate(lines):
        if l.startswith(ANCHOR_PREFIX) and " in 'Regression" + chr(92) in l:
            anchor = i
    assert anchor >= 0, 'no Test.Regression.* registration found'
    print('anchor line %d: %s' % (anchor + 1, lines[anchor]))
    before_bytes = len(raw)
    before_counts = dpr_stats(lines)
    new_lines = ['  // ' + label]
    for u in units:
        unit = 'Test.Regression.' + u
        line = "  %s in 'Regression%sTest.Regression.%s.pas'," % (unit, chr(92), u)
        if any(l.strip() == line.strip() for l in lines):
            print('already registered, skipping: %s' % unit)
            continue
        new_lines.append(line)
    lines[anchor + 1:anchor + 1] = new_lines
    out = CRLF.join(lines).encode('utf-8')  # no BOM added, no BOM expected
    # safety: every original line still present exactly once, in order
    old = raw.decode('utf-8').split(CRLF)
    new = out.decode('utf-8').split(CRLF)
    it = iter(new)
    assert all(any(l == o for l in it) for o in old), 'original line lost or reordered!'
    io.open(DPR, 'wb').write(out)
    assert chr(0xFFFD) not in out.decode('utf-8'), 'mojibake would be introduced'
    after_counts = dpr_stats(out.decode('utf-8').split(CRLF))
    print('bytes %d -> %d' % (before_bytes, len(out)))
    print('registered Test.Regression.* units: %d -> %d' % (before_counts, after_counts))
    return 0


def dpr_stats(lines):
    s = set()
    for l in lines:
        ls = l.strip()
        if ls.startswith('Test.Regression.') and ' in ' in ls:
            s.add(ls.split(' in ')[0].strip())
    return len(s)


if __name__ == '__main__':
    sys.exit(main())
