const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';

const pkgs = {
  'Core': ['20260918-Core-A-加密安全基础.md', '20260918-Core-B-并发插件.md',
           '20260918-Core-C-服务与类型层.md', '20260918-Core-D-i18n弹性.md'],
  'Features': ['20260918-Features-A-Browser桌面UIA.md', '20260918-Features-B-Commerce语音.md',
               '20260918-Features-C-防御云意图.md']
};

for (const dir of Object.keys(pkgs)) {
  let blob = '';
  for (const r of pkgs[dir]) {
    const p = path.join(ROOT, 'CodeReview', r);
    if (fs.existsSync(p)) blob += fs.readFileSync(p, 'utf8') + '\n';
  }
  const blobL = blob.toLowerCase();
  const all = fs.readdirSync(path.join(ROOT, dir)).filter(n => /\.pas$/i.test(n));
  const missing = all.filter(u => {
    const stem = u.replace(/\.pas$/i, '').toLowerCase();      // deepbase.intentclarification.router
    const short = stem.replace(/^deepbase\./, '');            // intentclarification.router
    return !blobL.includes(stem) && !blobL.includes(short);
  });
  console.log(`=== ${dir} ===  实际单元 ${all.length}，宽松匹配后仍未出现 ${missing.length} 个:`);
  missing.forEach(u => console.log('    ' + u));
  console.log('');
}
