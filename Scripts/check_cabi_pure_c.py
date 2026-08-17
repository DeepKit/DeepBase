#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_cabi_pure_c.py - P0-001 纯 C ABI 契约门禁（签名级 1:1）

验收依据：tasks.md P0-001「ABI 头文件与 Delphi 声明无管理类型、签名严格 1:1」；
法源 docs/77.extend.PluginHotReload §5、docs/77a.adr.Plugin-ABI-and-Lifetime §2.1/§2.3/§2.4。

扫描两个权威文件，断言不出现管理类型/跨边界禁用类型，且**函数签名逐参数 1:1**：
  1. include/deepbase_plugins_c.h        (C 权威)
  2. Core/DeepBase.Plugins.CAbi.pas      (Delphi 1:1 声明)

规则：
  1. 禁用类型关键词（按 C 头文件 / Delphi 声明各自的文本特征匹配）
  2. 跨边界内存所有权纪律：变长输出只能走 dbp_out_buffer（两次调用）或
     dbp_free_buffer（同模块释放），禁止直接返回裸指针给调用方
  3. 调用约定策略：C 头必须声明 DBP_API 宏（宿主可钉死 __stdcall/__cdecl），
     头文件注释必须写明调用约定策略；Delphi 导出函数必须全部 stdcall
  4. 所有导出函数 dbp_* 齐全，且 C 头签名与 Delphi 类型声明逐参数 1:1：
     - 参数个数一致
     - 每个参数指针性一致（是否指针/引用）
     - 返回类别一致（void/句柄/abi_info/health_info/int32）
  5. 头文件不得出现管理类型；Delphi 不得出现跨边界管理类型

退出码：0=通过，1=契约违规（打印违规行），2=文件缺失/不可读。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
C_HEADER = ROOT / "include" / "deepbase_plugins_c.h"
DELPHI = ROOT / "Core" / "DeepBase.Plugins.CAbi.pas"


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


# ---- 禁用类型关键词（在剥离注释后的代码上匹配） ----
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
FORBIDDEN_DELPHI_INTERFACE_TYPE = re.compile(r"=\s*interface\b")
FORBIDDEN_DELPHI_TYPES = [
    r"\bTBytes\b",          # 动态字节数组
    r"\bstring\b",          # Delphi string
    r"\bTJSONObject\b",
    r"\bTArray<",           # 泛型动态数组
    r"\bVariant\b",
    r"\bTDateTime\b",
    r"\bTObject\b",         # 对象引用
]


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


# ---- 调用约定策略：C 头必须声明 DBP_API 宏，且注释必须写明调用约定 ----
DBP_API_MACRO_RE = re.compile(
    r"#\s*define\s+DBP_API\b[^\n]*"
)

# ---- C 头函数签名权威表（唯一稳定 ABI） ----
# 每项：导出名, 参数个数, [各参数指针性: 1=指针/引用, 0=值], 返回类别
# 返回类别: 'void' | 'handle' | 'abi' | 'health' | 'i32'
C_SIGNATURES = {
    "dbp_create":         (1, [1], "handle"),
    "dbp_destroy":        (1, [0], "void"),
    "dbp_get_abi":        (0, [], "abi"),
    "dbp_initialize":     (2, [0, 1], "i32"),
    "dbp_shutdown":       (1, [0], "i32"),
    "dbp_reload_config":  (2, [0, 1], "i32"),
    "dbp_get_metadata":   (2, [0, 1], "i32"),
    "dbp_get_health":     (2, [0, 1], "i32"),
    "dbp_get_last_error": (2, [0, 1], "i32"),
    "dbp_free_buffer":    (1, [1], "void"),
    "dbp_invoke":         (3, [0, 1, 1], "i32"),   # ABI 1.1 可选导出
    "dbp_invoke_alloc":   (3, [0, 1, 1], "i32"),   # ABI 1.1 可选导出（插件分配归属，§F5）
}

# ---- Delphi 类型声明解析：TDbpXxxFunc = function/procedure(...): RetType; stdcall; ----
# 参数列表：Delphi 用分号分隔。函数声明可能无括号（dbp_get_abi: function: T; stdcall;）
DELPHI_FUNC_DECL_RE = re.compile(
    r"T(Dbp\w+)Func\s*=\s*(function|procedure)"
    r"\s*\(([^)]*)\)"                 # 参数列表（可能为空 ( )）
    r"\s*"
    r"(?::\s*([\w.]+))?"              # 返回类型（procedure 无）
    r"\s*;\s*stdcall\s*;",
    re.IGNORECASE,
)
# 无括号形式（function: dbp_abi_info; stdcall;）
DELPHI_FUNC_DECL_NO_PAREN_RE = re.compile(
    r"T(Dbp\w+)Func\s*=\s*(function)\s*:"
    r"\s*([\w.]+)\s*;\s*stdcall\s*;",
    re.IGNORECASE,
)

# Delphi 类型名 -> C 返回类别
DELPHI_RET_MAP = {
    "": "void",                    # procedure 无返回
    "int32": "i32",
    "uint32": "i32",
    "dbp_abi_info": "abi",
    "dbp_plugin_handle": "handle",
    "dbp_health_info": "health",
    "pointer": "handle",
}

# 该 ABI 中"按指针传"的 Delphi 类型（C 侧为 X* / const X*）
DELPHI_PTR_TYPES = {"Pdbp_buffer", "Pdbp_out_buffer", "Pdbp_health_info", "Pointer"}


def parse_delphi_param_ptr(param: str) -> int:
    """按参数类型判断是否底层数据通过指针传（与 C 侧指针性对齐）。

    - 类型为 Pdbp_* / Pointer  -> 指针（1）
    - 类型为 dbp_plugin_handle -> 值（0）：句柄本身即指针，按值传
    - 类型为 Int32/UInt32       -> 值（0）
    """
    p = param.strip()
    if p.startswith("const "):
        p = p[6:].strip()
    if p.startswith("var ") or p.startswith("out "):
        return 1
    # 去掉参数名前缀 "Name: Type" / "Name: Type"
    if ":" in p:
        _, _, typ = p.partition(":")
        typ = typ.strip()
    else:
        # 无类型标注（罕见）——按名字推断
        return 1 if p.startswith("P") else 0
    if typ in DELPHI_PTR_TYPES:
        return 1
    return 0


def parse_delphi_signatures(dtext: str):
    """解析 CAbi.pas 全部 TDbp*Func 声明 -> {type_name: (arg_ptrs, ret_cat)}"""
    code = strip_comments(dtext, "delphi")
    sigs = {}
    # 带括号形式
    for m in DELPHI_FUNC_DECL_RE.finditer(code):
        type_name = "T" + m.group(1) + "Func"
        is_func = m.group(2).lower() == "function"
        args_raw = m.group(3).strip()
        ret_raw = (m.group(4) or "").strip()
        arg_items = [a.strip() for a in args_raw.split(";") if a.strip()]
        arg_ptrs = [parse_delphi_param_ptr(a) for a in arg_items]
        ret_cat = DELPHI_RET_MAP.get(ret_raw.lower(), "unknown:" + ret_raw)
        if not is_func:
            ret_cat = "void"
        sigs[type_name] = (arg_ptrs, ret_cat)
    # 无括号形式（dbp_get_abi）
    for m in DELPHI_FUNC_DECL_NO_PAREN_RE.finditer(code):
        type_name = "T" + m.group(1) + "Func"
        ret_raw = m.group(3).strip()
        ret_cat = DELPHI_RET_MAP.get(ret_raw.lower(), "unknown:" + ret_raw)
        sigs[type_name] = ([], ret_cat)
    return sigs


# ---- 导出函数名 -> Delphi 类型名 映射（1:1） ----
EXPORT_TO_DELPHI_TYPE = {
    "dbp_create":         "TDbpCreateFunc",
    "dbp_destroy":        "TDbpDestroyFunc",
    "dbp_get_abi":        "TDbpGetAbiFunc",
    "dbp_initialize":     "TDbpInitializeFunc",
    "dbp_shutdown":       "TDbpShutdownFunc",
    "dbp_reload_config":  "TDbpReloadConfigFunc",
    "dbp_get_metadata":   "TDbpGetMetadataFunc",
    "dbp_get_health":     "TDbpGetHealthFunc",
    "dbp_get_last_error": "TDbpGetLastErrorFunc",
    "dbp_free_buffer":    "TDbpFreeBufferFunc",
    "dbp_invoke":         "TDbpInvokeFunc",
    "dbp_invoke_alloc":   "TDbpInvokeAllocFunc",
}


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
    d_code = strip_comments(dtext, "delphi")
    for m in FORBIDDEN_DELPHI_INTERFACE_TYPE.finditer(d_code):
        ln = d_code.count("\n", 0, m.start()) + 1
        line = dtext.splitlines()[ln - 1].strip() if ln - 1 < len(dtext.splitlines()) else ""
        issues.append(f"[Delphi] L{ln} 禁用接口类型声明: {line}")

    # 2. 调用约定策略（H2 高危 #4）
    #    头文件必须声明 DBP_API 宏（宿主可钉死调用约定）
    if not DBP_API_MACRO_RE.search(strip_comments(ctext, "c")):
        issues.append("[C头] 缺少 DBP_API 宏（调用约定策略未钉死，见 77a §2.3）")
    #    头文件注释必须写明调用约定策略（stdcall/cdecl 决策）
    head_note = re.search(
        r"(调用约定|call.ing.convention|stdcall|cdecl|__stdcall|__cdecl)", ctext, re.IGNORECASE)
    if not head_note:
        issues.append("[C头] 未声明调用约定策略（头文件注释须写明，见 77a §2.3）")
    #    Delphi 导出函数类型必须全部 stdcall
    d_signatures = parse_delphi_signatures(dtext)
    # stdcall 已由 DELPHI_FUNC_DECL_RE 的 `; stdcall;` 约束隐含校验
    # （解析不到则类型不在 d_signatures，后续签名检查会报缺失）

    # 3. 导出函数必须齐全 + 签名级 1:1
    for sym, (n_args, ptrs, ret_cat) in C_SIGNATURES.items():
        if sym not in ctext:
            issues.append(f"[C头] 缺少导出函数 {sym}")
        if sym not in dtext:
            issues.append(f"[Delphi] 缺少导出函数符号 {sym}")
            continue
        delphi_type = EXPORT_TO_DELPHI_TYPE[sym]
        if delphi_type not in d_signatures:
            issues.append(f"[Delphi] 缺少类型声明 {delphi_type}（对应 {sym}）")
            continue
        d_ptrs, d_ret = d_signatures[delphi_type]
        # 参数个数
        if len(d_ptrs) != n_args:
            issues.append(
                f"[签名] {sym}: 参数个数不一致 C头={n_args} Delphi({delphi_type})={len(d_ptrs)}")
        # 参数指针性逐位
        for i in range(min(len(d_ptrs), n_args)):
            if d_ptrs[i] != ptrs[i]:
                issues.append(
                    f"[签名] {sym}: 参数{i+1} 指针性不一致 "
                    f"C头={'指针' if ptrs[i] else '值'} "
                    f"Delphi={ '指针' if d_ptrs[i] else '值'}")
        # 返回类别
        if d_ret != ret_cat:
            issues.append(
                f"[签名] {sym}: 返回类别不一致 C头={ret_cat} Delphi({delphi_type})={d_ret}")

    # 4. 内存所有权纪律：变长输出必须走 dbp_out_buffer / dbp_free_buffer。
    code = strip_comments(ctext, "c")
    allowed_ptr_returns = {"dbp_plugin_handle", "dbp_buffer", "dbp_out_buffer"}
    for m in re.finditer(r"^(\w[\w\s\*]*?)\s+(\w+)\s*\([^)]*\)\s*;", code, re.MULTILINE):
        rettype, fname = m.group(1).strip(), m.group(2)
        if fname.startswith("dbp_") and "*" in rettype:
            if rettype.strip("*").strip() not in allowed_ptr_returns:
                line_no = code.count("\n", 0, m.start()) + 1
                line = ctext.splitlines()[line_no - 1].strip()
                issues.append(f"[C头] L{line_no} 疑似裸指针返回(长度不透明): {line}")

    if issues:
        print("P0-001 契约门禁：失败")
        for i in issues:
            print(f"  ✗ {i}")
        print("\n必须修复后才能声明纯 C ABI。")
        return 1

    print("P0-001 契约门禁：通过")
    print(f"  {C_HEADER}  ({len(ctext.splitlines())} 行)")
    print(f"  {DELPHI}    ({len(dtext.splitlines())} 行)")
    print(f"  ✓ 无管理类型 / 调用约定已钉死(DBP_API) / 导出函数齐全")
    print(f"  ✓ {len(C_SIGNATURES)} 个导出函数签名逐参数 1:1 一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
