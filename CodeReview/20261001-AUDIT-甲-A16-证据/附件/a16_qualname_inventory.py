#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""A16 判据 2「限定名守恒」清点器。

对比同一测试单元在两个口径下的：
  1) 夹具限定名清单（interface 段 [Test] 声明的 TFixture.Method）
  2) 断言调用清单（Assert.<Method> 的多重集，含参数首行归一化）

用法: python a16_qualname_inventory.sh <rev-or-WORK> <Tests/x.pas> [...]
  <rev>  git 修订号（取该修订下的文件内容）；WORK 表示工作树当前内容。
输出为可读清单 + 末尾的 CONSERVED / DRIFTED 判定，退出码 0=守恒 / 1=漂移。
"""
import re
import subprocess
import sys

def load(rev, path):
    if rev == "WORK":
        with open(path, "rb") as f:
            data = f.read()
    else:
        data = subprocess.check_output(["git", "show", "%s:%s" % (rev, path)])
    text = data.decode("utf-8-sig", errors="replace").replace("\r\n", "\n")
    return text

def iface_part(text):
    head = text.split("\nimplementation\n", 1)[0]
    return head

def test_methods(text):
    """夹具限定名清单：按 interface 段位置扫描，[TestFixture] 类名 + 其后的 [Test] procedure 声明。"""
    head = iface_part(text)
    marks = [(m.start(), m.group(1)) for m in
             re.finditer(r"\[TestFixture\]\s*\n\s*([A-Za-z_]\w*)\s*=\s*class", head)]
    qual = []
    for m in re.finditer(r"\[Test[^\]]*\]\s*\n\s*procedure\s+([A-Za-z_]\w*)\s*;", head):
        owner = None
        for mpos, mname in marks:
            if mpos < m.start():
                owner = mname
        qual.append("%s.%s" % (owner, m.group(1)))
    return [x[1] for x in marks], sorted(qual)

def assertions(text):
    items = []
    for m in re.finditer(r"Assert\.[A-Za-z_]\w*", text):
        items.append(m.group(0))
    # 断言消息文本也是断言集合的一部分：改基类时若顺手改了消息，同样算语义漂移
    msgs = []
    for m in re.finditer(r"'([^']{12,})'", text):
        s = m.group(1).strip()
        if s and not s.startswith("//"):
            msgs.append(re.sub(r"\s+", " ", s))
    return sorted(items), sorted(set(msgs))

def main():
    rev = sys.argv[1]
    paths = [p for p in sys.argv[2:] if p.endswith(".pas")]
    drift = 0
    for p in paths:
        a_text = load(rev, p)
        b_text = load("WORK", p)
        a_fix, a_m = test_methods(a_text)
        b_fix, b_m = test_methods(b_text)
        a_assert, a_msgs = assertions(a_text)
        b_assert, b_msgs = assertions(b_text)
        same_names = a_m == b_m
        same_assert = a_assert == b_assert
        # 消息只在「本口径下的既有断言」范围内比较：新增用例自带新消息不算漂移
        new_msgs = [x for x in b_msgs if x not in a_msgs]
        lost_msgs = [x for x in a_msgs if x not in b_msgs]
        print("=== %s @ %s vs WORK ===" % (p, rev))
        print("  fixtures: %s -> %s" % (a_fix, b_fix))
        print("  qualified test names: %d -> %d  conserved=%s" % (len(a_m), len(b_m), same_names))
        for n in a_m:
            print("    - %s" % n)
        print("  assert calls: %d -> %d  conserved=%s" % (len(a_assert), len(b_assert), same_assert))
        print("  assert multiset: %s" % a_assert)
        if not same_names:
            print("  METHOD DRIFT: +%s -%s" % (sorted(set(b_m) - set(a_m)), sorted(set(a_m) - set(b_m))))
        if not same_assert:
            print("  ASSERT DRIFT: +%s -%s" % (sorted(set(b_assert) - set(a_assert)), sorted(set(a_assert) - set(b_assert))))
        print("  message strings kept=%s lost=%d added=%d" % (len(lost_msgs) == 0, len(lost_msgs), len(new_msgs)))
        if lost_msgs:
            print("  LOST MESSAGES: %s" % lost_msgs)
        for n in new_msgs:
            print("  + new message (belongs to a test method listed above): %s" % n[:80])
        if not (same_names and same_assert and not lost_msgs):
            drift += 1
    print("VERDICT: %s" % ("DRIFTED" if drift else "CONSERVED"))
    sys.exit(1 if drift else 0)

main()
