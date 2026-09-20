"""K6 全库行尾收敛 — 干净集构建 + Schema.pas 多重CR 前置修复。
只读 git 事实 + 一处字节级修复；不做任何 git 写操作。
"""
import os
import subprocess

ROOT = r"D:/_Progs/02Business/DeepBase"
os.chdir(ROOT)

EXCLUDE_PREFIX = ("TestResults/",)
EXCLUDE_EXACT = ("Core/DeepBase.Schema.pas",)


def run(args):
    return subprocess.run(args, capture_output=True).stdout


def numstat_set(extra):
    out = run(["git", "-c", "core.quotepath=false", "diff", "--numstat", "-z"] + extra)
    s = set()
    for chunk in out.split(b"\0"):
        if not chunk:
            continue
        parts = chunk.split(b"\t", 2)
        if len(parts) == 3:
            s.add(parts[2].decode("utf-8", "surrogateescape"))
    return s


raw = numstat_set([])
ign = numstat_set(["--ignore-cr-at-eol"])
clean = sorted(p for p in (raw - ign)
               if not p.startswith(EXCLUDE_PREFIX) and p not in EXCLUDE_EXACT)

print("tracked-modified(raw) :", len(raw))
print("substantive(ign-eol)  :", len(ign))
print("clean set             :", len(clean))
from collections import Counter
ext = Counter(os.path.splitext(p)[1].lower() for p in clean)
print("clean set by ext      :", dict(sorted(ext.items(), key=lambda kv: -kv[1])))

# --- Schema.pas 多重 CR 前置修复（961 行 \r\r\r\r\n -> \r\n）---
p = os.path.join(ROOT, "Core", "DeepBase.Schema.pas")
d = open(p, "rb").read()
lone_b = sum(1 for i, b in enumerate(d) if b == 13 and (i + 1 >= len(d) or d[i + 1] != 10))
nd = d.replace(b"\r\r\r\r\n", b"\r\n")
lone_a = sum(1 for i, b in enumerate(nd) if b == 13 and (i + 1 >= len(nd) or nd[i + 1] != 10))
open(p, "wb").write(nd)
print("\nSchema.pas size        :", len(d), "->", len(nd))
print("  4cr+LF (^M^M^M^M$)    :", d.count(b"\r\r\r\r\n"), "->", nd.count(b"\r\r\r\r\n"))
print("  loneCR               :", lone_b, "->", lone_a)
print("  CRLF                 :", d.count(b"\r\n"), "->", nd.count(b"\r\n"))
print("  NUL                  :", nd.count(b"\x00"))
print("  BOM                  :", nd[:3] == b"\xef\xbb\xbf")

os.makedirs(os.path.join(ROOT, ".tmp", "k6"), exist_ok=True)
with open(os.path.join(ROOT, ".tmp", "k6", "cleanset.nul"), "wb") as fh:
    for f in clean:
        fh.write(f.encode("utf-8", "surrogateescape") + b"\0")
print("\nwrote .tmp/k6/cleanset.nul  (", len(clean), "entries, NUL-separated )")
