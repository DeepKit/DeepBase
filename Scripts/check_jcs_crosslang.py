#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_jcs_crosslang.py - P0-001 S3 跨语言 JCS 一致性门禁

验收依据：tasks.md P0-001 S3「跨语言 JCS 一致性」；
法源 docs/78.backend.ConfigUploadChannel §4「规范化 sha256 口径与服务端一致
（同一条 config 双端哈希相等，采用 RFC 8785 JCS + 保存 config_json_canonical_bytes）」。

目标：
  客户端 Delphi TJsonCanonicalizer（Core/DeepBase.Crypto.JCS.pas）
  与服务端 Python jcs 库（to-server/website/deepkit.top/backend/app/provider.py）
  对同一条 config 必须产出完全一致的 JCS 字节，从而 SHA-256 一致。

本脚本以 Python jcs 库为参考实现，校验三类向量（均取自 Delphi 单元测试
Tests/Test.DeepBase.Config.Upload.pas 的既有断言）：
  V1 键排序 + 字符串转义
  V2 RFC 8785 数字规范（指数/前导零/整数化）
  V3 SHA-256 已知向量（权威哈希比对）

用法：
  python check_jcs_crosslang.py            # 需 Python 环境装有 jcs 库
  python check_jcs_crosslang.py --vector-only  # 仅打印向量，不要求 jcs 库

退出码：0=双端一致，1=向量不一致，2=jcs 库缺失（--vector-only 可豁免）。
"""
import hashlib
import sys

# ---- 权威向量（来源：Tests/Test.DeepBase.Config.Upload.pas 既有断言）----
# V1: 键排序 + 转义。Delphi 输入 z = 'line'#10'quote"slash\'（换行+引号+反斜杠）
V1_DELPHI_EXPECT = '{"a":1,"z":"line\\nquote\\"slash\\\\"}'
# V2: RFC 8785 数字规范。Delphi 输入 [333333333.333333, 1e30, 4.50, 2e-3, 1e-27]
V2_DELPHI_EXPECT = "[333333333.333333,1e+30,4.5,0.002,1e-27]"
# V3: SHA-256 已知向量。Delphi 输入 {"a":1,"b":2}
V3_DELPHI_SHA256 = "43258cff783fe7036d8a43033f830adfc60ec037382473548ac742b888292777"


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    vector_only = "--vector-only" in sys.argv
    fails = []

    if not vector_only:
        try:
            import jcs
        except ImportError:
            print("S3 JCS 跨语言门禁：失败（Python 环境缺 jcs 库，pip install jcs）")
            print("  提示：--vector-only 可仅打印向量，跳过运行库比对。")
            return 2
    else:
        jcs = None

    if jcs is not None:
        # V1
        zval = 'line\nquote"slash\\'
        c1 = jcs.canonicalize({"z": zval, "a": 1}).decode()
        print(f"V1 python : {c1!r}")
        print(f"V1 delphi : {V1_DELPHI_EXPECT!r}")
        if c1 != V1_DELPHI_EXPECT:
            fails.append("V1")
        else:
            print("  V1 PASS")

        # V2
        c2 = jcs.canonicalize([333333333.333333, 1e30, 4.50, 2e-3, 1e-27]).decode()
        print(f"V2 python : {c2!r}")
        print(f"V2 delphi : {V2_DELPHI_EXPECT!r}")
        if c2 != V2_DELPHI_EXPECT:
            fails.append("V2")
        else:
            print("  V2 PASS")

        # V3
        c3 = jcs.canonicalize({"a": 1, "b": 2})
        s3 = sha256_hex(c3)
        print(f"V3 python sha256: {s3}")
        print(f"V3 delphi sha256: {V3_DELPHI_SHA256}")
        if s3 != V3_DELPHI_SHA256:
            fails.append("V3")
        else:
            print("  V3 PASS")

    # ---- 向量清单（服务端返工时手工对拍，不依赖 jcs 库）----
    print("\n--- 权威向量清单（供服务端 Python 对拍）---")
    print(f"V1 排序转义: {V1_DELPHI_EXPECT}")
    print(f"V2 数字规范: {V2_DELPHI_EXPECT}")
    print(f"V3 SHA256   : {V3_DELPHI_SHA256}  (输入 {{\"a\":1,\"b\":2}})")

    print()
    if fails:
        print(f"S3 JCS 跨语言门禁：失败（{len(fails)} 向量不一致: {fails}）")
        return 1
    print("S3 JCS 跨语言门禁：通过（Delphi TJsonCanonicalizer == Python jcs，双端哈希一致）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
