# -*- coding: utf-8 -*-
"""F5/判据6 编译探针生成器：从 HEAD 原件做字节级手术，保证 mojibake 字节原样保留。

产出（每个用例独立目录，含 Template.AutoUpdateBootstrap.pas + TPLBOOTProbe.dpr）：
  F5-head            HEAD 原件（预期红：6 属性 + ucStable（可能还有 TThread）E2003）
  F5-fixed           仅把 L44-L50 六行换成合法赋值，并向 implementation uses 补 System.Classes
                     （预期绿：证明这六行+该 uses 是唯一编译阻断面）
  NC1-typo           F5-fixed 基础上把 UpdateUrl 写成 UpdateUrll（预期 E2003）
  NC2-missing-uses   F5-fixed 基础上删掉 uses 里的 DeepBase.VCL.AutoUpdater 一行（预期 E2003）
"""
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, '..', '..', 'Examples', 'Templates', 'Common', 'Template.AutoUpdateBootstrap.pas')
OUT = os.path.join(ROOT, '_probe_out')

data = open(SRC, 'rb').read()
lines = data.split(b'\n')  # 本文件为纯 LF（eol_baseline pas_lf_exceptions）

# 1-based 行号 -> 0-based 索引
# L44-L50: AutoCheck / Channel / ShowDialogOnUpdate / EnablePolicyDrivenSilentUpdate /
#          SilentInstallPollIntervalMs / AutoTriggerExitInstall / SilentInstallMainExePath
assert lines[43].strip().startswith(b'GAutoUpdater.AutoCheck'), lines[43]
assert lines[44].strip().startswith(b'GAutoUpdater.Channel'), lines[44]
assert lines[49].strip().startswith(b'GAutoUpdater.SilentInstallMainExePath'), lines[49]

FIXED_BLOCK = [
    b'  GAutoUpdater.AutoCheck := False;',
    b"  GAutoUpdater.UpdateUrl := '';",
    b"  GAutoUpdater.CurrentVersion := '0.0.0';",
]

def emit(name, unit_lines):
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, 'Template.AutoUpdateBootstrap.pas'), 'wb') as f:
        f.write(b'\n'.join(unit_lines))
    dpr = (
        'program TPLBOOTProbe;\n\n'
        '{$APPTYPE CONSOLE}\n\n'
        'uses\n'
        '  System.SysUtils,\n'
        '  Template.AutoUpdateBootstrap;\n\n'
        'begin\n'
        "  Writeln('probe linked: Template.AutoUpdateBootstrap uses OK');\n"
        'end.\n'
    )
    with open(os.path.join(d, 'TPLBOOTProbe.dpr'), 'w', encoding='ascii', newline='\n') as f:
        f.write(dpr)
    print('emitted', name)

# F5-head: 原样
emit('F5-head', lines)

# F5-fixed: 替换 L44-L50（idx 43-49）＋ 拆开 L58 被注释吞掉的 ForceQueue 调用行。
# 注意：TThread 经 interface uses 的 System.Classes 已在本单元全境可见，implementation 无需也不得重复列。
# L58 = idx 57：一行 `  // ...检查?  TThread.ForceQueue(nil,` —— // 注释吞掉调用本身（E2029 根因），
# 连 ca3364e 祖先也是这个结构。从原件字节原位拆分，不手写任何中文，避免二次转写误差。
l58 = lines[57]
cut = l58.index(b'TThread.ForceQueue(nil,')
fixed = lines[:43] + FIXED_BLOCK + lines[50:57] + [l58[:cut].rstrip(), b'  ' + l58[cut:]] + lines[58:]
emit('F5-fixed', fixed)

# NC1-typo: F5-fixed 的 UpdateUrl -> UpdateUrll
nc1 = [l.replace(b'GAutoUpdater.UpdateUrl', b'GAutoUpdater.UpdateUrll') for l in fixed]
assert any(b'UpdateUrll' in l for l in nc1)
emit('NC1-typo', nc1)

# NC2-missing-uses: F5-fixed 删掉 DeepBase.VCL.AutoUpdater 一行
nc2 = [l for l in fixed if b'DeepBase.VCL.AutoUpdater' not in l]
assert not any(b'DeepBase.VCL.AutoUpdater' in l for l in nc2)
emit('NC2-missing-uses', nc2)

print('done')
