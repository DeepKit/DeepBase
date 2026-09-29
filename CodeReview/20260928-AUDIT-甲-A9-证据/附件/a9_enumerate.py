import subprocess, re, sys, io, os

def git(*a):
    return subprocess.run(['git', '-c', 'core.quotePath=false'] + list(a),
                          capture_output=True, text=True, encoding='utf-8').stdout

tracked = [p for p in git('ls-files', '-z').split('\0') if p.endswith('.pas')]

def dpr_member(unit_name, dpr_path):
    if not os.path.exists(dpr_path):
        return 'NO_DPR'
    txt = open(dpr_path, encoding='utf-8-sig', errors='replace').read()
    forms = []
    if re.search(r'\b' + re.escape(unit_name) + r"\s+in\s+'", txt):
        forms.append("in'...'")
    if re.search(r'(^|[\s,])' + re.escape(unit_name) + r'\s*,', txt, re.M):
        forms.append('bare,')
    return '+'.join(forms) if forms else '-'

MAIN = 'Tests/DeepBaseTests.dpr'
INTEG = 'Tests/Integration/DeepBaseIntegrationTests.dpr'

out = []
for p in sorted(tracked):
    raw = open(p, encoding='utf-8-sig', errors='replace').read()
    if '[TestFixture]' not in raw:
        continue
    reg = re.findall(r'RegisterTestFixture\s*\(\s*([A-Za-z0-9_]+)', raw)
    # fixture classes: declaration lines '  TXxx = class' preceded (attr line) by [TestFixture]
    lines = raw.replace('\r\n', '\n').split('\n')
    fx = []
    for i, ln in enumerate(lines):
        if ln.strip() == '[TestFixture]':
            for j in range(i + 1, min(i + 6, len(lines))):
                m = re.match(r'\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*class', lines[j])
                if m:
                    fx.append(m.group(1))
                    break
    missing = [c for c in fx if c not in reg]
    if not missing and not fx:
        continue
    if not missing:
        continue
    ntest = len(re.findall(r'\[Test\b', raw))
    out.append({
        'unit': p,
        'fixtures': fx,
        'registered': reg,
        'missing': missing,
        'testMethods': ntest,
        'mainDpr': dpr_member(os.path.basename(p)[:-4], MAIN),
        'integDpr': dpr_member(os.path.basename(p)[:-4], INTEG),
    })

print('HEAD ' + git('rev-parse', '--short', 'HEAD').strip())
print('scope: git ls-files *.pas (whole repo, not only Tests/**)')
print('units with [TestFixture] and >=1 fixture class lacking RegisterTestFixture: %d' % len(out))
for r in out:
    print('---')
    print('unit      : %s' % r['unit'])
    print('fixtures  : %s' % ','.join(r['fixtures']))
    print('registered: %s' % (','.join(r['registered']) or '(none)'))
    print('MISSING   : %s' % ','.join(r['missing']))
    print('[Test]    : %d' % r['testMethods'])
    print('mainDpr   : %s' % r['mainDpr'])
    print('integDpr  : %s' % r['integDpr'])
