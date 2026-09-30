#!/usr/bin/env bash
# 主控自建反事实（甲 A11 同范）：逐项换回旧形态，新用例必须真变红。
# 每项跑完立即 git checkout 还原并核验工作树干净，绝不在树上留改动。
set -u
export MSYS2_ARG_CONV_EXCL='*'
WT=/d/_ProgData/DeepBase-MC-B13/wt-89ba4a8
OUT=/d/_ProgData/DeepBase-MC-B13
cd "$WT" || exit 99

run_fixture () {  # $1=unit  $2=logfile
  DEEPBASE_EXTRA_U="$(pwd -W)/ThirdParty/Payment" \
    bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_run_fixture.sh "$1" > "$2" 2>&1
  echo "OUTER_EXIT=$?" >> "$2"
}

summary () {
  rg -a "RUNNER_STATS|RUN_EXIT|OUTER_EXIT|BUILD_EXIT" "$1" | tail -6
  echo "-- 失败明细（前 25 行）--"
  rg -a "FAILED|Condition|Expected|Actual|no assertions|Did not raise|Raised" "$1" | head -25
}

clean_check () {
  local s; s=$(git status --porcelain | rg -v '^\?\? \.tmp/')
  if [ -n "$s" ]; then echo "!!!! 树脏（须立即查）: $s"; else echo "== 还原核验：工作树干净 =="; fi
}

echo "######## CF-1 B13-01：写出口换回 DateToISO8601(SDKNotif.PaidAt, False) ########"
perl -pi -e 's/DateToISO8601\(TTimeZone\.Local\.ToUniversalTime\(SDKNotif\.PaidAt\), True\)/DateToISO8601(SDKNotif.PaidAt, False)/' Features/DeepBase.Commerce.PaymentBridge.pas
rg -n "PaidAtISO := DateToISO8601" Features/DeepBase.Commerce.PaymentBridge.pas
run_fixture Tests/Test.DeepBase.Commerce.PaymentBridge.pas "$OUT/cf1.txt"
summary "$OUT/cf1.txt"
git checkout -- Features/DeepBase.Commerce.PaymentBridge.pas
clean_check

echo
echo "######## CF-2 B13-02：接缝改回按本地解释 DateTimeToUnix(v, False) ########"
perl -pi -e 's/DateTimeToUnix\(ANowUtcBare \+ AExpireMinutes \/ 1440\);/DateTimeToUnix(ANowUtcBare + AExpireMinutes \/ 1440, False);/' ThirdParty/Payment/DeepBase.Payment.Stripe.pas
rg -n "Result := DateTimeToUnix" ThirdParty/Payment/DeepBase.Payment.Stripe.pas
run_fixture Tests/Test.DeepBase.Payment.pas "$OUT/cf2.txt"
summary "$OUT/cf2.txt"
git checkout -- ThirdParty/Payment/DeepBase.Payment.Stripe.pas
clean_check

echo
echo "######## CF-3 B13-03：接缝去掉 IncHour(...,8)（换回不换算的 +08:00 形态）########"
perl -0777 -pi -e 's/IncHour\(ANowUtcBare \+ AExpireMinutes \/ 1440, 8\)/ANowUtcBare + AExpireMinutes \/ 1440/' ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas
rg -n "ANowUtcBare \+ AExpireMinutes" ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas
run_fixture Tests/Test.DeepBase.Payment.pas "$OUT/cf3.txt"
summary "$OUT/cf3.txt"
git checkout -- ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas
clean_check

echo
echo "######## CF-4 B13-04：换回 850f49b 的零断言用例（探针面须红 1 例）########"
git show 850f49b:Tests/Test.DeepBase.Commerce.PaymentBridge.pas > Tests/Test.DeepBase.Commerce.PaymentBridge.pas
run_fixture Tests/Test.DeepBase.Commerce.PaymentBridge.pas "$OUT/cf4.txt"
summary "$OUT/cf4.txt"
git checkout -- Tests/Test.DeepBase.Commerce.PaymentBridge.pas
clean_check

echo
echo "######## CF-5 调用点盲区自证：两处生产调用点换回裸 Now（接缝不动）########"
perl -pi -e 's/WeChatTimeExpire\(TTimeZone\.Local\.ToUniversalTime\(Now\), AOrder\.ExpireMinutes\)/WeChatTimeExpire(Now, AOrder.ExpireMinutes)/' ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas
perl -pi -e 's/StripeExpiresAtUnix\(TTimeZone\.Local\.ToUniversalTime\(Now\), AOrder\.ExpireMinutes\)/StripeExpiresAtUnix(Now, AOrder.ExpireMinutes)/' ThirdParty/Payment/DeepBase.Payment.Stripe.pas
rg -n "WeChatTimeExpire\(Now|StripeExpiresAtUnix\(Now" ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas ThirdParty/Payment/DeepBase.Payment.Stripe.pas
run_fixture Tests/Test.DeepBase.Payment.pas "$OUT/cf5.txt"
summary "$OUT/cf5.txt"
git checkout -- ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas ThirdParty/Payment/DeepBase.Payment.Stripe.pas
clean_check

echo
echo "######## 还原后同面复跑（两项夹具须回到全绿）########"
run_fixture Tests/Test.DeepBase.Commerce.PaymentBridge.pas "$OUT/cf-restore-pb.txt"
summary "$OUT/cf-restore-pb.txt"
run_fixture Tests/Test.DeepBase.Payment.pas "$OUT/cf-restore-pay.txt"
summary "$OUT/cf-restore-pay.txt"
clean_check
echo "ALL_CF_DONE"
