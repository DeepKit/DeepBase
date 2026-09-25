#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""B2-12 同族缺陷取证扫描：找出全库跨文件重复的接口 GUID。

为什么需要：工单只点名 DeepFlow.Role.pas 单元内部的两对撞车。修本单时要回答
「这是孤例还是一族」，并把不属于本单的部分整表登记给主控（乙不越单修）。
判定口径见输出文件抬头；产物是纯文本明细，不做退出码门禁（长期拦截应由主控立项）。
"""
import re
import subprocess
import sys
import collections

GUID = re.compile(r"\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
                  r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}")
# 归属名：GUID 字面量所在行的上文里，最近的接口声明或 TGUID 常量声明
DECL = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*interface")
CONST = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*TGUID")


def tracked_pas():
    out = subprocess.check_output(["git", "ls-files", "-z"])
    names = [n.decode("utf-8") for n in out.split(b"\0") if n.endswith(b".pas")]
    # TLB 导入生成物里同一 GUID 在接口/IID/注释三处重复是生成器约定，不是缺陷
    return [n for n in names if not n.endswith("_TLB.pas")]


def owner(lines, idx):
    for j in range(idx, max(-1, idx - 6), -1):
        m = DECL.search(lines[j])
        if m:
            return m.group(1)
        m = CONST.search(lines[j])
        if m:
            return "const:" + m.group(1)
    return "?"


def main():
    occ = collections.defaultdict(list)
    for path in tracked_pas():
        try:
            with open(path, encoding="utf-8-sig", errors="replace") as f:
                lines = f.read().splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines):
            for m in GUID.finditer(line):
                occ[m.group(0).upper()].append((path, i + 1, owner(lines, i)))

    dups = {g: v for g, v in occ.items() if len({x[0] for x in v}) > 1}
    print("扫描 .pas（排除 *_TLB.pas）：%d 个不同 GUID，其中跨文件重复 %d 个"
          % (len(occ), len(dups)))
    for g, v in sorted(dups.items()):
        print(g)
        for path, line, name in v:
            print("    %s:%d  %s" % (path, line, name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
