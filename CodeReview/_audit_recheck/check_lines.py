import io, sys, os

ROOT = r"D:\_Progs\02Business\DeepBase"

CHECKS = [
    # (file, start, end, expected_symbol_hint)
    ("Core/DeepBase.Manifest.Verifier.pas", 205, 232, "签名校验失败仍放行"),
    ("Features/DeepBase.UIA.Engine.pas", 449, 452, "IsMappingIntegrityVerified 恒 True"),
    ("Core/DeepBase.EHAI.Types.pas", 306, 315, "CreateExplicit 无限额授权包络"),
    ("Core/DeepBase.Security.pas", 299, 340, "主口令 machine-id+$USER"),
    ("Core/DeepBase.Crypto.Hash.pas", 474, 532, "VerifyPassword 读算法/迭代"),
    ("Core/DeepBase.Crypto.PBKDF2.pas", 70, 88, "HMAC 补零"),
    ("Core/DeepBase.Authorization.pas", 1614, 1622, "ThreadID 键裸 TUser 指针"),
    ("Core/DeepBase.Template.pas", 2080, 2088, "SSTI 任意文件读"),
    ("Core/DeepBase.Reflection.pas", 398, 404, "RTTI 共享 context 悬垂"),
    ("Features/DeepBase.Browser.CDP.pas", 905, 1011, "WaitForSelector 匿名线程 UAF"),
    ("Core/DeepBase.KeyManager.pas", 742, 784, "keystore 就地截断写入"),
    ("Features/DeepBase.AntiTamper.pas", 278, 284, "U+FFFD 字面量"),
    ("Core/DeepBase.LogAlert.pas", 1131, 1140, "缓冲区只 Add 无 Clear"),
    ("Core/DeepBase.LLM.pas", 470, 498, "SaveConfig Description 写空"),
]

def read_lines(path):
    with io.open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()

for rel, s, e, hint in CHECKS:
    p = os.path.join(ROOT, rel.replace("/", os.sep))
    print("=" * 78)
    print("FILE: %s  [%d-%d]  期望: %s" % (rel, s, e, hint))
    if not os.path.isfile(p):
        print("  !! 文件不存在")
        continue
    lines = read_lines(p)
    print("  总行数: %d" % len(lines))
    if e > len(lines):
        print("  !! 行号超出文件末尾（%d > %d）" % (e, len(lines)))
        e = len(lines)
    for i in range(s, min(e, len(lines)) + 1):
        print("  %5d| %s" % (i, lines[i - 1][:160]))
