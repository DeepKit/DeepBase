"""D6 段3 取证：DoQryDemo 补上 Datasnap 命名空间后到底还缺什么（WO-20260923-AUDIT-甲-D6）。

门禁对「无 .dproj 的工程」用 DEFAULT_NS（check_build.js:39），其中没有 Datasnap；
doQry/prjDoQry.dproj 自己配了 Datasnap，所以同族两件一件绿一件红。本脚本用与门禁
buildDefaultEnv 同构的参数（UNIT_DIRS + Win64 RTL lib + DUnitX 源）手动编目标工程，
只改 -NS 一处，用来判定主控裁定「DBClient 不在 Win64 lib 面，属平台不适用」的前提是否成立。

用法（在仓根或任意子目录下）：
    python CodeReview/20260923-AUDIT-甲-D6-证据/d6_seg3_doqry_probe.py            # 原样 DEFAULT_NS
    python .../d6_seg3_doqry_probe.py ";Datasnap"                                  # 只补 Datasnap
    python .../d6_seg3_doqry_probe.py ";Datasnap;Vcl.Samples" doQry/prjDoQry.dpr   # 指定目标
产物落在 <仓根>/.tmp/d6_seg3_doqry_out/（dcu/exe），不污染源码目录。
"""
import os
import subprocess
import sys

BDS = r'D:\Program Files (x86)\Embarcadero\Studio\37.0'
DUNITX = r'D:\ProgramData\delphi\DUnitX\Source'
# 与 check_build.js:37 UNIT_DIRS 逐字一致
UNIT_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance',
             'ThirdParty/Payment', 'ThirdParty/Social', 'Tools/CLI',
             'Tools/WebService', 'Tests', 'Tests/Regression', 'Tests/Integration']
# 与 check_build.js:39 DEFAULT_NS 逐字一致
BASE_NS = ('System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;'
           'FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win')


def repo_root():
    d = os.path.dirname(os.path.abspath(__file__))
    # 链接工作树里的 .git 是文件不是目录，故用 exists。
    while not os.path.exists(os.path.join(d, '.git')):
        up = os.path.dirname(d)
        if up == d:
            sys.exit('找不到仓根（.git）')
        d = up
    return d


ROOT = repo_root()
extra = sys.argv[1] if len(sys.argv) > 1 else ''
target = sys.argv[2] if len(sys.argv) > 2 else 'doQry/examples/DoQryDemo/DoQryDemo.dpr'

dirs = [os.path.abspath(os.path.join(ROOT, d)) for d in UNIT_DIRS]
dirs += [os.path.join(BDS, 'lib', 'Win64', 'release'),
         os.path.join(BDS, 'lib', 'Win64', 'debug'), DUNITX]
out = os.path.join(ROOT, '.tmp', 'd6_seg3_doqry_out')
os.makedirs(out + '/dcu', exist_ok=True)
os.makedirs(out + '/exe', exist_ok=True)

args = [os.path.join(BDS, 'bin', 'dcc64.exe'), '-Q', '-B', '-DDEBUG',
        '-U' + ';'.join(dirs), '-NS' + BASE_NS + extra,
        '-N0' + out + '/dcu', '-E' + out + '/exe',
        os.path.abspath(os.path.join(ROOT, target))]
print('NS =', BASE_NS + extra)
# .dpr 里的 `in '..\..\src\X.pas'` 按工程目录相对解析，门禁也是 cwd=projDir 跑的，这里同构。
r = subprocess.run(args, capture_output=True, text=True, encoding='utf-8', errors='replace',
                   cwd=os.path.abspath(os.path.join(ROOT, os.path.dirname(target))))
print('\n'.join(l for l in (r.stdout + r.stderr).splitlines()
                if any(k in l for k in ('Fatal', 'Error', 'Warning', 'Hint')))[:6000])
print('EXIT=%d' % r.returncode)
