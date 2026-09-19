// 乙-B4 构建登记：DeepBase.ManagedWorker 进 Core 包；Test.DeepBase.ManagedWorker 进测试工程
// 幂等：已存在登记则跳过。用法: node b4_register.js
const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';

function patch(file, anchorRe, insertFn, label) {
  const p = path.join(ROOT, file);
  let t = fs.readFileSync(p, 'utf8');
  if (t.includes('DeepBase.ManagedWorker') || t.includes('Test.DeepBase.ManagedWorker')) {
    console.log('SKIP(already registered):', label); return;
  }
  const m = t.match(anchorRe);
  if (!m) { console.error('ANCHOR NOT FOUND in ' + file + ' :: ' + anchorRe); process.exit(1); }
  t = t.replace(anchorRe, (mm) => mm + insertFn(mm));
  fs.writeFileSync(p, t);
  console.log('OK:', label);
}

// 1) dpk：Manager.Operational 条目后插（保持逗号结构：Operational 行以 "，\r\n" 结尾格式已知）
patch('DeepBaseCore.dpk',
  /[ \t]*DeepBase\.Manager\.Operational in 'Core\\DeepBase\.Manager\.Operational\.pas',\r?\n/,
  (mm) => (mm.endsWith('\r\n') ? '' : '\r\n') + "  DeepBase.ManagedWorker in 'Core\\DeepBase.ManagedWorker.pas',\r\n",
  'DeepBaseCore.dpk contains');

// 2) Core dproj
patch('DeepBaseCore.dproj',
  /<DCCReference Include="Core\\DeepBase\.Manager\.Operational\.pas"\/>\r?\n/,
  () => '        <DCCReference Include="Core\\DeepBase.ManagedWorker.pas"/>\r\n',
  'DeepBaseCore.dproj DCCReference');

// 3) 测试 dpr
patch('Tests/DeepBaseTests.dpr',
  /[ \t]*Test\.DeepBase\.Manager in 'Test\.DeepBase\.Manager\.pas',\r?\n/,
  () => "  Test.DeepBase.ManagedWorker in 'Test.DeepBase.ManagedWorker.pas',\r\n",
  'DeepBaseTests.dpr uses');

// 4) 测试 dproj
patch('Tests/DeepBaseTests.dproj',
  /<DCCReference Include="Test\.DeepBase\.Manager\.pas"\/>\r?\n/,
  () => '        <DCCReference Include="Test.DeepBase.ManagedWorker.pas"/>\r\n',
  'DeepBaseTests.dproj DCCReference');
