// 乙 最终提交清单生成：classify.json 分类结果 - 甲独占/②类 pathspec + 乙新产物
const fs = require('fs');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const c = JSON.parse(fs.readFileSync(ROOT + '/.tmp/b5/classify.json', 'utf8'));
const jiaRe = [
  /^Core\/DeepBase\.Crypto/, /^Features\/DeepBase\.(Updater|AutoUpdate|UIA)/, /^Governance\//,
  /^Core\/DeepBase\.HB\./, /(^|\/)(VCL|FMX)\/.*\.HB\./, /^Tests\/.*\.HB\./,
  /^Features\/UIAutomationClient_TLB\.pas$/,
];
const isJia = p => jiaRe.some(re => re.test(p));
const include = [];
const excludedJia = [];
for (const p of [...c.bomOnly, ...c.eolBomOnly, ...c.sub_YI_B1, ...c.sub_YI_surgical, ...c.sub_MIXED_YI]) {
  if (isJia(p)) excludedJia.push(p); else include.push(p);
}
// 乙的构建/CI 文件（diff 已核实纯乙内容）
include.push('DeepBaseCore.dpk', 'DeepBaseCore.dproj', 'Tests/DeepBaseTests.dpr', 'Tests/DeepBaseTests.dproj', '.github/workflows/delphi-ci.yml');
// 乙新增未跟踪产物
include.push('Core/DeepBase.ManagedWorker.pas', 'Tests/Test.DeepBase.ManagedWorker.pas',
  '09_工程脚本/build-ownership', '09_工程脚本/encoding-gate',
  'CodeReview/20260919-全库审计-锚点核验表.md', 'CodeReview/_audit_recheck/乙-B5-取证',
  'CodeReview/20260919-AUDIT-乙-交付回执.md', 'CodeReview/20260919-AUDIT-乙-请求审核报告.md');
const uniq = [...new Set(include)].sort();
fs.writeFileSync(ROOT + '/.tmp/b5/addlist.txt', uniq.join('\n') + '\n');
fs.writeFileSync(ROOT + '/.tmp/b5/excludedJia.txt', excludedJia.sort().join('\n') + '\n');
console.log({ include: uniq.length, excludedJia: excludedJia.length });
console.log('excludedJia:', excludedJia.join(' | '));
