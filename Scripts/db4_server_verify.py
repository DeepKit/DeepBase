#!/usr/bin/env python3
"""
DB4 服务端 API 契约验证脚本
用法: python db4_server_verify.py --base-url https://api-test.deepkit.top

验证服务端返回格式是否符合 Delphi 客户端 (TDeepKitSafeClient) 的预期.
"""

import argparse
import json
import sys
import time
import uuid
import hashlib
import hmac
import base64
from urllib.request import Request, urlopen
from urllib.error import HTTPError


class APIClient:
    def __init__(self, base_url: str, api_key: str = ""):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.access_token = None
        self.refresh_token = None

    def _headers(self):
        h = {"Content-Type": "application/json"}
        if self.api_key:
            h["X-API-Key"] = self.api_key
        if self.access_token:
            h["Authorization"] = f"Bearer {self.access_token}"
        return h

    def _request(self, method: str, path: str, body=None) -> dict:
        url = f"{self.base_url}{path}"
        data = json.dumps(body).encode() if body else None
        req = Request(url, data=data, headers=self._headers(), method=method)
        try:
            with urlopen(req) as resp:
                return json.loads(resp.read().decode())
        except HTTPError as e:
            body = e.read().decode()
            print(f"  FAIL: {method} {path} -> {e.code}: {body}")
            return None

    # Auth
    def auth_login_device(self, app_id: str, device_id: str) -> bool:
        print(f"\n[1] POST /dk/auth/login")
        resp = self._request("POST", "/dk/auth/login", {
            "login_type": "device_anonymous",
            "device_id": device_id,
            "device_fingerprint": f"fp_{uuid.uuid4().hex[:16]}"
        })
        if not resp:
            return False

        required = ["user_id", "access_token", "refresh_token", "expires_in"]
        missing = [k for k in required if k not in resp]
        if missing:
            print(f"  FAIL: 缺少字段 {missing}")
            return False

        self.access_token = resp["access_token"]
        self.refresh_token = resp["refresh_token"]
        print(f"  OK: user_id={resp['user_id']}, expires_in={resp['expires_in']}")
        return True

    def auth_me(self) -> bool:
        print(f"\n[2] GET /dk/auth/me")
        resp = self._request("GET", "/dk/auth/me")
        if not resp:
            return False

        required = ["user_id", "display_name", "is_active"]
        missing = [k for k in required if k not in resp]
        if missing:
            print(f"  FAIL: 缺少字段 {missing}")
            return False

        print(f"  OK: user_id={resp['user_id']}, is_active={resp['is_active']}")
        return True

    # Users
    def ensure_user(self, provider: str, provider_user_id: str, app_id: str) -> bool:
        print(f"\n[3] POST /commerce/users/ensure")
        resp = self._request("POST", "/commerce/users/ensure", {
            "provider": provider,
            "provider_user_id": provider_user_id,
            "app_id": app_id,
        })
        if not resp:
            return False

        if "user_id" not in resp:
            print(f"  FAIL: 缺少 user_id")
            return False

        print(f"  OK: user_id={resp['user_id']}")
        return True

    # Products
    def list_products(self, app_id: str) -> bool:
        print(f"\n[4] GET /commerce/products?app_id={app_id}")
        resp = self._request("GET", f"/commerce/products?app_id={app_id}")
        if not resp:
            return False

        items = resp.get("items")
        if items is None:
            print(f"  FAIL: 缺少 items 数组")
            return False

        print(f"  OK: {len(items)} products")
        for p in items[:3]:
            print(f"    - {p.get('product_id')}: {p.get('name')} "
                  f"({p.get('amount_minor', 0) / 100:.2f} {p.get('currency', 'CNY')})")
        return True

    # Orders
    def create_order(self, user_id: str, app_id: str, product_id: str) -> dict:
        print(f"\n[5] POST /commerce/orders")
        resp = self._request("POST", "/commerce/orders", {
            "user_id": user_id,
            "app_id": app_id,
            "product_id": product_id,
        })
        if not resp:
            return None

        required = ["order_id", "out_trade_no", "status", "amount_minor"]
        missing = [k for k in required if k not in resp]
        if missing:
            print(f"  FAIL: 缺少字段 {missing}")
            return None

        print(f"  OK: order_id={resp['order_id']}, status={resp['status']}")
        return resp

    def close_order(self, order_id: str) -> bool:
        print(f"\n[6] POST /commerce/orders/{order_id}/close")
        resp = self._request("POST", f"/commerce/orders/{order_id}/close")
        if not resp:
            return False

        status = resp.get("status")
        if status != "closed":
            print(f"  FAIL: 期望 status=closed, 实际 {status}")
            return False

        print(f"  OK: status={status}")
        return True

    # Payment Intent
    def create_payment_intent(self, order_id: str, provider: str, channel: str,
                               payer_open_id: str = "") -> bool:
        print(f"\n[7] POST /commerce/payments/intents (Idempotency-Key)")
        idempotency_key = f"idem_{uuid.uuid4().hex[:16]}"
        url = f"{self.base_url}/commerce/payments/intents"
        body = json.dumps({
            "order_id": order_id,
            "provider": provider,
            "channel": channel,
            "payer_open_id": payer_open_id,
        }).encode()

        headers = self._headers()
        headers["Idempotency-Key"] = idempotency_key
        req = Request(url, data=body, headers=headers, method="POST")
        try:
            with urlopen(req) as resp:
                data = json.loads(resp.read().decode())
        except HTTPError as e:
            print(f"  FAIL: {e.code}: {e.read().decode()}")
            return False

        required = ["payment_id", "provider"]
        missing = [k for k in required if k not in data]
        if missing:
            print(f"  FAIL: 缺少字段 {missing}")
            return False

        # 至少应有 prepay_id 或 pay_url 或 qr_code_data
        has_pay_data = any(k in data for k in ["prepay_id", "pay_url", "qr_code_data"])
        if not has_pay_data:
            print(f"  WARN: 无支付数据 (prepay_id/pay_url/qr_code_data)")

        print(f"  OK: payment_id={data['payment_id']}")

        # 幂等验证: 重复提交应返回相同结果
        print(f"\n[7b] 幂等验证 (重复 Idempotency-Key)")
        req2 = Request(url, data=body, headers=headers, method="POST")
        try:
            with urlopen(req2) as resp2:
                data2 = json.loads(resp2.read().decode())
        except HTTPError as e:
            print(f"  FAIL: 重复请求失败 {e.code}")
            return False

        if data2.get("payment_id") != data.get("payment_id"):
            print(f"  FAIL: 幂等失效 — 第一次 {data.get('payment_id')}, "
                  f"第二次 {data2.get('payment_id')}")
            return False

        print(f"  OK: 幂等通过")
        return True

    # License Snapshot
    def issue_license_snapshot(self, app_id: str, device_id: str) -> dict:
        print(f"\n[8] POST /dk/license/snapshot/issue")
        resp = self._request("POST", "/dk/license/snapshot/issue", {
            "app_id": app_id,
            "device_id": device_id,
        })
        if not resp:
            return None

        required = ["snapshot_id", "issued_at", "expires_at", "payload",
                     "signature", "key_id", "schema_version"]
        missing = [k for k in required if k not in resp]
        if missing:
            print(f"  FAIL: 缺少字段 {missing}")
            return None

        # 验证 schema_version
        if resp["schema_version"] != 1:
            print(f"  FAIL: schema_version 应为 1, 实际 {resp['schema_version']}")
            return None

        # 验证 payload 结构
        payload = resp["payload"]
        if not isinstance(payload, (dict, str)):
            print(f"  FAIL: payload 类型错误 {type(payload)}")
            return None

        print(f"  OK: snapshot_id={resp['snapshot_id']}, "
              f"key_id={resp['key_id']}, "
              f"expires_at={resp['expires_at']}")
        print(f"      signature={resp['signature'][:32]}...")
        return resp

    def refresh_license_snapshot(self, app_id: str, device_id: str) -> bool:
        print(f"\n[9] POST /dk/license/snapshot/refresh")
        resp = self._request("POST", "/dk/license/snapshot/refresh", {
            "app_id": app_id,
            "device_id": device_id,
        })
        if not resp:
            return False

        if "snapshot_id" not in resp:
            print(f"  FAIL: 缺少 snapshot_id")
            return False

        print(f"  OK: new snapshot_id={resp['snapshot_id']}")
        return True

    # Entitlements
    def list_entitlements(self, app_id: str) -> bool:
        print(f"\n[10] GET /commerce/entitlements")
        resp = self._request("GET",
                             f"/commerce/entitlements?app_id={app_id}")
        if not resp:
            return False

        items = resp.get("items")
        if items is None:
            print(f"  FAIL: 缺少 items")
            return False

        print(f"  OK: {len(items)} entitlements")
        return True


def main():
    parser = argparse.ArgumentParser(description="DB4 服务端 API 契约验证")
    parser.add_argument("--base-url", required=True, help="服务端 URL")
    parser.add_argument("--api-key", default="", help="API Key")
    parser.add_argument("--app-id", default="desktop_tool", help="应用 ID")
    parser.add_argument("--product-id", default="pro_monthly", help="产品 ID")
    args = parser.parse_args()

    print(f"=" * 60)
    print(f"DB4 服务端 API 契约验证")
    print(f"Base URL: {args.base_url}")
    print(f"=" * 60)

    client = APIClient(args.base_url, args.api_key)
    device_id = f"verify_{uuid.uuid4().hex[:12]}"
    results = {}

    # 1. Auth
    results["auth_login"] = client.auth_login_device(args.app_id, device_id)
    if not results["auth_login"]:
        print("\n✗ Auth login failed, aborting remaining tests")
        sys.exit(1)

    results["auth_me"] = client.auth_me()

    # 2. Users
    results["ensure_user"] = client.ensure_user(
        "wechat_miniprogram", f"openid_{uuid.uuid4().hex[:12]}", args.app_id)

    # 3. Products
    results["list_products"] = client.list_products(args.app_id)

    # 4. Orders (需要有效 user_id 和 product_id)
    # 先用 auth_me 获取 user_id
    user_resp = client._request("GET", "/dk/auth/me")
    if user_resp:
        user_id = user_resp["user_id"]
        order = client.create_order(user_id, args.app_id, args.product_id)
        if order:
            results["create_order"] = True
            # 关闭订单
            results["close_order"] = client.close_order(order["order_id"])

            # 支付意向 (新订单)
            order2 = client.create_order(user_id, args.app_id, args.product_id)
            if order2:
                results["payment_intent"] = client.create_payment_intent(
                    order2["order_id"], "wechat_pay", "mini_program",
                    "openid_test")
        else:
            results["create_order"] = False
    else:
        results["create_order"] = False

    # 5. License Snapshot
    snapshot = client.issue_license_snapshot(args.app_id, device_id)
    results["issue_snapshot"] = snapshot is not None
    if snapshot:
        results["refresh_snapshot"] = client.refresh_license_snapshot(
            args.app_id, device_id)

    # 6. Entitlements
    results["list_entitlements"] = client.list_entitlements(args.app_id)

    # Summary
    print(f"\n{'=' * 60}")
    print(f"验证结果汇总")
    print(f"{'=' * 60}")

    passed = sum(1 for v in results.values() if v)
    total = len(results)

    for name, ok in results.items():
        status = "✓ PASS" if ok else "✗ FAIL"
        print(f"  {status}  {name}")

    print(f"\n{passed}/{total} 通过")

    if passed == total:
        print("\n✓ 所有 API 契约验证通过! 客户端可正常对接.")
    else:
        print(f"\n✗ {total - passed} 项验证失败. 请检查服务端实现.")

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
