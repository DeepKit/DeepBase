// 构建归属门禁负向样本测试
//   法源：WO-20260919-AUDIT-乙 B3（违规必须拦截：注入孤儿/新轨入包/生产 uses 新轨 ⇒ 报错）
//         WO-20260924-AUDIT-乙-D7（扫描本身失败绝不能报绿：root 指错/空扫描/参数不合法 ⇒ EXIT=3）
// 用例分三组，缺一不可：
//   T1 违规面：老用例（O1/O2/O4 各自命中、已入构建的单元不被误判）。夹具自 D7 起补齐八个生产目录，
//      否则树本身先撞上覆盖面守卫（EXIT=3），测不到 O1——那是拿夹具掩盖门禁，不是门禁的问题。
//   T2 fail-closed 面：root 不存在 / 空目录 / 构建文件面为 0 / 生产单元面为 0 / 大小写变体参数，
//      五型各自 EXIT=3，且报错文案带失败路径（可取证，不是只给个非零码）。
//   T3 修前对照（反空转）：把「修前」的两个缺陷形态（walk 吞 readdir 错误 + 不做空扫描守卫）+
//      一个指错的默认根重放到同源副本上 ⇒ 同一夹具下旧形态必须 EXIT=0 假绿。
//      没有这组对照，T2 的断言只证明"我写的判断句会打印"，不证明"它拦住了真会发生的事"。
//   T4 正向对照：结构完整且干净的最小树 ⇒ EXIT=0，证明 fail-closed 没有过度兜底。
// 用法: node test_negative_sample.js   （退出码 0=门禁按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const HERE = __dirname;
const GATE = path.join(HERE, 'check_build_ownership.js');
const NL = String.fromCharCode(10);
const PROD_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tools', 'DeepFlow'];

let failed = false;
const note = (m) => console.log(m);
const fail = (m) => { console.error(m); failed = true; };

function run(args) {
  try {
    const out = execFileSync(process.execPath, args, { stdio: 'pipe' });
    return { code: 0, text: out.toString('utf8') };
  } catch (e) {
    return { code: e.status === undefined ? -1 : e.status, text: ((e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8')) };
  }
}
// 只带 generatedFrom + orphans 的最小可信基线：空 orphans 让任何孤儿都算「新增」。
function trustBaseline(dir) {
  const p = path.join(dir, 'baseline_empty.json');
  fs.writeFileSync(p, JSON.stringify({ generatedFrom: 'build-ownership/test_negative_sample.js', orphans: {} }));
  return p;
}
function mkTree(prefix) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  for (const d of PROD_DIRS) fs.mkdirSync(path.join(tmp, d), { recursive: true });
  return tmp;
}
function unit(dir, name) {
  fs.writeFileSync(path.join(dir, 'Core', name + '.pas'), `unit ${name};${NL}interface${NL}implementation${NL}end.${NL}`);
}

// ── T1 违规面：孤儿 / 新轨入生产包 / 生产单元 uses 新轨 ────────────────────────
{
  const tmp = mkTree('owngate-');
  unit(tmp, 'Bar');
  unit(tmp, 'FooOrphan');
  fs.writeFileSync(path.join(tmp, 'Core', 'Evil.pas'), `unit Evil;${NL}interface${NL}uses${NL}  DeepBase.Plugins.Manager;${NL}implementation${NL}end.${NL}`);
  fs.writeFileSync(path.join(tmp, 'prod.dpk'), `package prod;${NL}contains${NL}  Bar,${NL}  DeepBase.Plugins.Manager;`);
  const baseline = trustBaseline(tmp);
  const r = run([GATE, '--root', tmp, '--baseline', baseline]);
  if (r.code === 0) fail('T1 门禁未拦截任何违规（EXIT=0）\n' + r.text);
  for (const tag of ['O1', 'O2', 'O4']) {
    if (!r.text.includes(tag)) fail(`T1 缺少 ${tag} 报错（O3 因夹具无新轨 Manager.pas 文件不适用）\n${r.text}`);
  }
  if (!/O1 FAIL 新增孤儿单元[^\n]*FooOrphan\.pas/.test(r.text)) fail('T1 未报出注入的孤儿 FooOrphan.pas\n' + r.text);
  if (/O1 FAIL[^\n]*\/Bar\.pas/.test(r.text)) fail('T1 O1 误报已入构建单元 Bar.pas\n' + r.text);
  if (r.code !== 1) fail(`T1 违规应以 EXIT=1 结束，实际 EXIT=${r.code}`);
  else note('T1 通过：孤儿/新轨入包/生产 uses 新轨各自命中 O1/O2/O4，已入构建单元不误报');
  fs.rmSync(tmp, { recursive: true, force: true });
}

// ── T2 fail-closed 五型 ────────────────────────────────────────────────────────
const FC = [];
{
  const tmp = mkTree('owngate-dir-');
  const baseline = trustBaseline(tmp);
  // ① root 指向不存在目录（旧缺陷的正面形态：默认根写死在别的机器/CI 上就是这个状态）
  FC.push(['root 不存在', [GATE, '--root', path.join(tmp, 'no_such_dir'), '--baseline', baseline],
    /无法读取目录[^\n]*no_such_dir/, 3]);
  // ② root 存在但空（连 PROD_DIRS 都没有）
  const empty = path.join(tmp, 'empty');
  fs.mkdirSync(empty, { recursive: true });
  FC.push(['root 空目录', [GATE, '--root', empty, '--baseline', baseline], /无法读取目录|扫描 0 个/, 3]);
  // ③ 生产单元面正常、构建文件面为 0 ⇒ 引用关系无从判定
  const nobuild = path.join(tmp, 'nobuild');
  for (const d of PROD_DIRS) fs.mkdirSync(path.join(nobuild, d), { recursive: true });
  fs.mkdirSync(path.join(nobuild, 'Core'), { recursive: true });
  fs.writeFileSync(path.join(nobuild, 'Core', 'OrphanX.pas'), `unit OrphanX;${NL}interface${NL}implementation${NL}end.${NL}`);
  FC.push(['构建文件面为 0', [GATE, '--root', nobuild, '--baseline', baseline], /扫描 0 个构建文件/, 3]);
  // ④ 有构建文件、生产单元面为 0 ⇒ root 指错或被同名文件遮蔽
  const noprod = path.join(tmp, 'noprod');
  for (const d of PROD_DIRS) fs.mkdirSync(path.join(noprod, d), { recursive: true });
  fs.writeFileSync(path.join(noprod, 'prod.dpk'), `package prod;${NL}contains${NL}  Nothing;`);
  FC.push(['生产单元面为 0', [GATE, '--root', noprod, '--baseline', baseline], /扫描 0 个生产单元/, 3]);
  // ⑤ 大小写变体参数：旧私有 arg() 用大小写敏感的 indexOf 取不到 key，会静默回落默认根照常报绿
  FC.push(['--ROOT 大小写变体', [GATE, '--ROOT', nobuild, '--baseline', baseline], /大小写不符/, 3]);
}
for (const [name, args, re, want] of FC) {
  const r = run(args);
  if (r.code !== want) fail(`T2 ${name} 未以 EXIT=${want} 拒绝放行，实际 EXIT=${r.code}\n${r.text}`);
  else if (!re.test(r.text)) fail(`T2 ${name} EXIT=${want} 但未声明原因（取证链断裂）\n${r.text}`);
  else note(`T2 通过：${name} ⇒ EXIT=3 fail-closed（文案可定位）`);
}

// ── T3 修前对照：旧形态在「默认根指错」的同一夹具下必须假绿 ────────────────────
{
  const src = fs.readFileSync(GATE, 'utf8');
  const anchors = [
    ["    root: path.join(__dirname, '../..'),", "    root: path.join(__dirname, 'no_such_default_root'), // 「修前」对照：默认根指向不存在的路径（等价于写死在别的检出目录）",
    ],
    ['    die(`无法读取目录 ${dir} (${e.code || e.message})`);', '    return out; // 「修前」对照：readdir 失败被吞成空扫描'],
    ['if (buildFiles.length === 0) die(', '// 「修前」对照：空扫描不做守卫\nif (false) die('],
    ['if (prodUnits.length === 0) die(', 'if (false) die('],
  ];
  let patched = src;
  for (const [a, b] of anchors) {
    if (!patched.includes(a)) { fail(`T3 修前对照异常：未在门禁源码上定位锚点 ${JSON.stringify(a.slice(0, 40))}`); patched = null; break; }
    patched = patched.replace(a, b);
  }
  if (patched) {
    patched = patched.replace(/require\('\.\.\/([\w-]+)'\)/g, (m, mod) => 'require(' + JSON.stringify(path.resolve(HERE, '..', mod + '.js')) + ')');
    const tmp = mkTree('owngate-before-');
    unit(tmp, 'Bar');
    fs.writeFileSync(path.join(tmp, 'prod.dpk'), `package prod;${NL}contains Bar;`);
    const beforeGate = path.join(tmp, 'check_before.js');
    fs.writeFileSync(beforeGate, patched);
    const before = run([beforeGate, '--baseline', path.join(HERE, 'build_ownership_baseline.json')]);
    // 不传 --root：默认根（对照里指错）+ 吞掉的 readdir 失败 + 无空扫描守卫 ⇒ 0 违规 0 单元，旧代码报绿。
    if (before.code !== 0) fail(`T3 修前对照失败：旧形态未假绿（EXIT=${before.code}）⇒ 对照不成立\n${before.text}`);
    else if (!/构建归属门禁通过/.test(before.text)) fail(`T3 修前对照异常：EXIT=0 但无「通过」结论（可能没跑到判定）\n${before.text}`);
    else note('T3 通过：默认根指错的同一夹具下，旧形态扫空气仍报「门禁通过」（假绿实锤，新形态见 T2①）');
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

// ── T4 正向对照：结构完整且干净的树必须放行（防过度兜底）──────────────────────
{
  const tmp = mkTree('owngate-ok-');
  unit(tmp, 'Bar');
  fs.writeFileSync(path.join(tmp, 'prod.dpk'), `package prod;${NL}contains Bar;`);
  const baseline = trustBaseline(tmp);
  const r = run([GATE, '--root', tmp, '--baseline', baseline]);
  if (r.code !== 0) fail(`T4 正向对照失败：干净树被拦（EXIT=${r.code}）⇒ fail-closed 过度兜底\n${r.text}`);
  else note('T4 通过：干净最小树放行（覆盖面守卫未误伤正常调用）');
  fs.rmSync(tmp, { recursive: true, force: true });
}

console.log(failed ? 'OWNERSHIP-NEGATIVE-TEST: FAIL' : 'OWNERSHIP-NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
