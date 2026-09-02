# WeChat4x Schema Fixture（结构 only）

来源：WeChat 4.1.13.12 生产账号 dump（2026-09-02），账号已脱敏为 `wxid_<redacted>`。

| 文件 | 用途 |
|---|---|
| Msg_sample.txt | 一张 Msg_* 的 PRAGMA table_info |
| Name2Id.txt / TimeStamp.txt / wcdb_builtin_compression_record.txt | 静态表列信息 |
| meta.txt | 版本与冻结指纹（无生产 wxid） |

冻结 Msg 17 列签名 SHA256：
`26d53fe31f389e65779419dc30bfdd73df5f1c299215fa4a0dccd525910cda84`
注册前缀：`26d53fe31f`
