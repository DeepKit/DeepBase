#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_cabi_pure_c.py - P0-001 纯 C ABI 契约门禁（确定性扫描）

验收依据：tasks.md P0-001「ABI 头文件与 Delphi 声明无管理类型」；
法源 docs/77.extend.PluginHotReload §5、docs/77a.adr §2.3。

扫描两个权威文件，断言不出现管理类型/跨边界禁用类型：
  1. include/deepbase_plugins_c.h        (C 权威)
  2. Core/DeepBase.Plugins.CAbi.pas      (Delphi 1:1 声明)

规则：
  - 禁用类型关键词（按 C 头文件 / Delphi 声明各自的文本特征匹配）
  - 跨边界内存所有权纪律：变长输出只能走 dbp_out_buffer（两次调用）或
    dbp_free_buffer（同模块释放），禁止直接返回裸指针给调用方
  - 所有导出函数必须 stdcall + 固定符号名（dbp_*）

退出码：0=通过，1=契约违规（打印违规行），2=文件缺失/不可读。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
C_HEADER = ROOT / "include" / "deepbase_plugins_c.h"
DELPHI = ROOT / "Core" / "DeepBase.Plugins.CAbi.pas"

# ---- 注释剥离 ----
# Delphi: 花括号 { }、圆括号 (* *)、行 //；C: 块 /* */、行 //
def strip_comments(text: str, lang: str) -> str:
    out = []
    i, n = 0, len(text)
    while i < n:
        if lang == "delphi" and text.startswith("{", i):
            j = text.find("}", i)
            i = n if j < 0 else j + 1
        elif lang == "delphi" and text.startswith("(*", i):
            j = text.find("*)", i)
            i = n if j < 0 else j + 2
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
        elif text.startswith("/*", i):
            j = text.find("*/", i)
            i = n if j < 0 else j + 2
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


# 禁用类型关键词（在剥离注释后的代码上匹配）
FORBIDDEN_C = [
    r"\bclass\b",           # C++ 类
    r"\btemplate\b",        # C++ 模板
    r"\bstd::",             # C++ 标准库
    r"\bstring\b",          # C++ string
    r"\bvector\b",          # C++ vector
    r"\bCString\b",         # MFC
    r"\bVariant\b",
]
# Delphi 接口类型声明：`Xxx = interface`（interface 用作类型声明而非分区关键字）
# 注意：不能整体禁用 `interface`——它是 Delphi 单元分区关键字（unit 必须有
# interface/implementation 区）。只禁"接口类型声明"（type IXxx = interface ...）。
FORBIDDEN_DELPHI_INTERFACE_TYPE = re.compile(r"=\s*interface\b")
# 其它禁用管理类型（跨边界）
FORBIDDEN_DELPHI_TYPES = [
    r"\bTBytes\b",          # 动态字节数组
    r"\bstring\b",          # Delphi string
    r"\bTJSONObject\b",
    r"\bTArray<",           # 泛型动态数组
    r"\bVariant\b",
    r"\bTDateTime\b",
    r"\bTObject\b",         # 对象引用
]


def strip_comments(text: str, lang: str) -> str:
    """剥离注释，保持行数不变（注释内容替换为空格，行号对齐原文件）。
    支持跨行块注释（Delphi {} / (* *)、C /* */）与行注释（//）。"""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if lang == "delphi" and c == "{":
            j = text.find("}", i)
            end = n if j < 0 else j + 1
            out.append(" " * (end - i))
            i = end
        elif lang == "delphi" and text.startswith("(*", i):
            j = text.find("*)", i)
            end = n if j < 0 else j + 2
            out.append(" " * (end - i))
            i = end
        elif text.startswith("//", i):
            j = text.find("\n", i)
            end = n if j < 0 else j + 1
            out.append(" " * (end - i))
            i = end
        elif text.startswith("/*", i):
            j = text.find("*/", i)
            end = n if j < 0 else j + 2
            out.append(" " * (end - i))
            i = end
        else:
            out.append(c)
            i += 1
    return "".join(out)


def find_lines_without_comments(text: str, pat: str, lang: str):
    """返回匹配行号+行内容（已剥离注释）。行号与原文件一致。"""
    code = strip_comments(text, lang)
    result = []
    orig_lines = text.splitlines()
    for m in re.finditer(pat, code, re.IGNORECASE):
        line_no = code.count("\n", 0, m.start()) + 1
        line = orig_lines[line_no - 1].strip() if line_no - 1 < len(orig_lines) else ""
        result.append((line_no, line))
    return result


def main() -> int:
    issues = []
    if not C_HEADER.is_file() or not DELPHI.is_file():
        print("P0-001 契约门禁：失败（文件缺失）")
        for p in (C_HEADER, DELPHI):
            if not p.is_file():
                print(f"  ✗ 缺失 {p}")
        return 2

    ctext = C_HEADER.read_text(encoding="utf-8-sig")
    dtext = DELPHI.read_text(encoding="utf-8-sig")

    # 1. 禁用类型扫描（剥离注释后）
    for pat in FORBIDDEN_C:
        for ln, line in find_lines_without_comments(ctext, pat, "c"):
            issues.append(f"[C头] L{ln} 禁用类型 {pat}: {line}")
    for pat in FORBIDDEN_DELPHI_TYPES:
        for ln, line in find_lines_without_comments(dtext, pat, "delphi"):
            issues.append(f"[Delphi] L{ln} 禁用类型 {pat}: {line}")
    # 接口类型声明（type IXxx = interface）
    d_code = strip_comments(dtext, "delphi")
    for m in FORBIDDEN_DELPHI_INTERFACE_TYPE.finditer(d_code):
        ln = d_code.count("\n", 0, m.start()) + 1
        line = dtext.splitlines()[ln - 1].strip() if ln - 1 < len(dtext.splitlines()) else ""
        issues.append(f"[Delphi] L{ln} 禁用接口类型声明: {line}")

    # 2. 导出函数必须齐全（1:1 契约）
    required_symbols = [
        "dbp_create", "dbp_destroy", "dbp_get_abi",
        "dbp_initialize", "dbp_shutdown", "dbp_reload_config",
        "dbp_get_metadata", "dbp_get_health", "dbp_get_last_error",
        "dbp_free_buffer",
    ]
    for sym in required_symbols:
        if sym not in ctext:
            issues.append(f"[C头] 缺少导出函数 {sym}")
        if sym not in dtext:
            issues.append(f"[Delphi] 缺少导出函数 {sym}")

    # 3. 内存所有权纪律：变长输出必须走 dbp_out_buffer / dbp_free_buffer。
    #    允许返回：int32_t / uint32_t / void / dbp_abi_info / dbp_health_info /
    #    dbp_plugin_handle（不透明句柄）。禁止裸指针返回（长度不透明）。
    allowed_ptr_returns = {"dbp_plugin_handle", "dbp_buffer", "dbp_out_buffer"}
    code = strip_comments(ctext, "c")
    for m in re.finditer(r"^(\w[\w\s\*]*?)\s+(\w+)\s*\([^)]*\)\s*;", code, re.MULTILINE):
        rettype, fname = m.group(1).strip(), m.group(2)
        if fname.startswith("dbp_") and "*" in rettype:
            if rettype.strip("*").strip() not in allowed_ptr_returns:
                line_no = code.count("\n", 0, m.start()) + 1
                line = ctext.splitlines()[line_no - 1].strip()
                issues.append(f"[C头] L{line_no} 疑似裸指针返回(长度不透明): {line}")

    # 4. stdcall 纪律：Delphi 导出函数类型必须全部 stdcall（且 C 头不得有调用约定）
    stdcall_count = len(re.findall(r";\s*stdcall;", dtext))
    if stdcall_count < len(required_symbols):
        issues.append(f"[Delphi] 导出函数 stdcall 声明不齐（期望>=10，实得{stdcall_count}）")
    if re.search(r"\bstdcall\b", ctext, re.IGNORECASE):
        issues.append("[C头] 不应出现调用约定 stdcall（C 头用默认 cdecl）")

    if issues:
        print("P0-001 契约门禁：失败")
        for i in issues:
            print(f"  ✗ {i}")
        print("\n必须修复后才能声明纯 C ABI。")
        return 1

    print("P0-001 契约门禁：通过")
    print(f"  {C_HEADER}  ({len(ctext.splitlines())} 行)")
    print(f"  {DELPHI}    ({len(dtext.splitlines())} 行)")
    print("  ✓ 无管理类型 / 无裸指针变长输出 / 导出函数齐全 / stdcall 一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
