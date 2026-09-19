// 乙-B3 C1+C3：新轨 DeepBase.Plugins.* 6 单元冻结隔离
//  C1 消解同名类：Manager.pas 内 TDeepBasePluginManager → TDllPluginManager（避免与旧轨 Core\DeepBase.PluginManager.pas 静默遮蔽）
//  C3 文件头显式标记：[FROZEN — NOT IN BUILD — DO NOT USE IN PRODUCTION]
// 字节级 UTF-8 编辑，保留 BOM 与行尾风格。
const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const FILES = ['CAbi', 'CAbiLoader', 'Contracts', 'Manager', 'SafeGuard', 'Verifier']
  .map(n => path.join(ROOT, 'Core', `DeepBase.Plugins.${n}.pas`));

for (const f of FILES) {
  let buf = fs.readFileSync(f);
  const hasBom = buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF;
  let txt = hasBom ? buf.slice(3).toString('utf8') : buf.toString('utf8');
  const nl = txt.includes('\r\n') ? '\r\n' : '\n';
  if (!txt.startsWith('// [FROZEN')) {
    const banner = [
      '// [FROZEN — NOT IN BUILD — DO NOT USE IN PRODUCTION]',
      '// 法源：WO-20260919-AUDIT-乙 B3 / H10（主控终裁 2f011fd）：插件生产唯一真相源 =',
      '// 旧轨 Core\\DeepBase.PluginManager.pas（BPL）。本单元冻结隔离：不进任何 .dpk/.dproj，',
      '// 禁止生产 uses；复活须满足 B3-C5 四条件。同名类已按 C1 消解（TDllPluginManager）。'
    ].join(nl) + nl;
    txt = banner + txt;
  }
  const before = (txt.match(/TDeepBasePluginManager/g) || []).length;
  txt = txt.split('TDeepBasePluginManager').join('TDllPluginManager');
  fs.writeFileSync(f, Buffer.concat([hasBom ? Buffer.from([0xEF, 0xBB, 0xBF]) : Buffer.alloc(0), Buffer.from(txt, 'utf8')]));
  console.log(path.basename(f), '| renamed:', before);
}
