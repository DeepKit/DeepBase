// 托管拷贝门禁负向样本测试（WO-20260919-AUDIT-乙-R2 E7）
// 向临时目录注入：
// 1. Move(...SizeOf(string)) 托管类型裸拷贝（M1 违规）
// 2. 空基线下新增 FillChar 裸内存操作（M2 违规）
// 3. 正向样本：纯逐元素赋值的 .pas 必须通过
// 断言门禁逐项拦截并输出相应违规标识。
// 用法: node test_negative_sample.js （退出码 0=门禁按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const HERE = __dirname;

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mcgate-'));
fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });

// 正向样本：托管数组逐元素赋值，无裸内存原语
fs.writeFileSync(path.join(tmp, 'src', 'Ok.pas'),
  'unit Ok;\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf8');

// 负向样本 1：对 string 元素数组做 Move 批量拷贝（违规 M1 + M2）
fs.writeFileSync(path.join(tmp, 'src', 'Bad_M1.pas'), Buffer.from(
  'unit Bad_M1;\r\ninterface\r\nuses System.SysUtils;\r\n' +
  'procedure CopyStrings(const Src: TArray<string>; var Dst: TArray<string>);\r\n' +
  'begin\r\n  SetLength(Dst, Length(Src));\r\n' +
  '  Move(Src[0], Dst[0], Length(Src) * SizeOf(string));\r\nend;\r\n' +
  'implementation\r\nend.\r\n', 'utf8'));

// 负向样本 2：空基线下新文件出现 FillChar（违规 M2）
fs.writeFileSync(path.join(tmp, 'src', 'Bad_M2.pas'), Buffer.from(
  'unit Bad_M2;\r\ninterface\r\nimplementation\r\n' +
  'procedure Wipe(var Buf; N: Integer);\r\n' +
  'begin\r\n  FillChar(Buf, N, 0);\r\nend;\r\nend.\r\n', 'utf8'));

const emptyBaseline = path.join(tmp, 'empty_baseline.json');
fs.writeFileSync(emptyBaseline, JSON.stringify({ files: {} }, null, 2), 'utf8');

let failed = false;
let stdoutErr = '';
try {
  execFileSync(process.execPath, [path.join(HERE, 'check_managed_copy.js'), '--root', tmp, '--baseline', emptyBaseline], { stdio: 'pipe' });
  console.error('负向样本测试失败：门禁未拦截任何违规！');
  failed = true;
} catch (e) {
  stdoutErr = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8');
  console.log('门禁输出（预期包含 M1, M2 违规）:\n' + stdoutErr);
  for (const tag of ['M1', 'M2']) {
    if (!stdoutErr.includes(tag)) {
      console.error('缺少 ' + tag + ' 报错');
      failed = true;
    }
  }
}

// 正向路径：仅含 Ok.pas 的干净目录必须通过（防门禁过杀）
const clean = fs.mkdtempSync(path.join(os.tmpdir(), 'mcgate-ok-'));
fs.mkdirSync(path.join(clean, 'src'), { recursive: true });
fs.writeFileSync(path.join(clean, 'src', 'Ok.pas'), 'unit Ok;\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf8');
try {
  execFileSync(process.execPath, [path.join(HERE, 'check_managed_copy.js'), '--root', clean, '--baseline', emptyBaseline], { stdio: 'pipe' });
  console.log('正向样本通过：OK');
} catch (e) {
  console.error('正向样本被误拦截！\n' + (e.stderr || Buffer.alloc(0)).toString('utf8'));
  failed = true;
}

fs.rmSync(tmp, { recursive: true, force: true });
fs.rmSync(clean, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
