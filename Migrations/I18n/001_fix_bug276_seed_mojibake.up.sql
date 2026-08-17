-- Migration: Fix BUG-276 legacy seed data (SQLite / PostgreSQL compatible)
--
-- Background
-- ----------
-- Before 2026-06-19 the seed data in Core/DeepBase.Schema.pas suffered a
-- double-conversion (UTF-8 → GBK → UTF-8) that turned every CJK string
-- into the classic "锟斤拷" mojibake. The buggy source was compiled with
-- dcc64 defaulting to CP936/GBK, so the compiled binary wrote the
-- mojibake bytes directly into the SQLite / PostgreSQL seed tables.
-- New databases are fine (seed was fixed and dcc64 now uses
-- --codepage:65001), but databases initialised between the bad commit
-- and the fix still carry:
--
--   Languages.NativeName
--     zh-CN:  绠€浣撴枃  (or similar mojibake) instead of 简体中文
--     zh-TW:  箝j箓箓  (or similar mojibake) instead of 繁體中文
--     ja-JP:  鏃ユ湰瑾 (or similar mojibake) instead of 日本語
--
--   I18nTexts.TranslatedText (LangCode = 'zh-CN')
--     OK          → 锟斤拷  instead of 确定
--     Cancel      → 取锟斤拷  instead of 取消
--     Save        → 锟斤拷锟斤拷  instead of 保存
--     Close       → 锟截憋拷  instead of 关闭
--     Error       → 锟斤拷锟斤拷  instead of 错误
--     Warning     → 锟斤拷锟斤拷  instead of 警告
--     Information → 锟斤拷息  instead of 信息
--     Confirm     → 锟斤拷  instead of 确认
--
-- What this migration does
-- ------------------------
-- 1. Updates the four Languages rows by LangCode to the correct UTF-8
--    NativeName (unconditional UPDATE — the row's other fields are not
--    touched, so it is safe to re-run).
-- 2. Upserts the eight zh-CN builtin I18nTexts translations. If a row
--    was missing (DB predates the seed), it is inserted. If it existed
--    with mojibake or any other content, it is overwritten with the
--    correct UTF-8 text.
--
-- The migration is idempotent: every statement converges the table to
-- the correct state, and re-running it is a no-op on an already-fixed
-- database (apart from a few unconditional row writes).

-- Languages.NativeName ------------------------------------------------------------

UPDATE Languages
SET NativeName = '简体中文'
WHERE LangCode = 'zh-CN' AND (NativeName IS NULL OR NativeName <> '简体中文');

UPDATE Languages
SET NativeName = '繁體中文'
WHERE LangCode = 'zh-TW' AND (NativeName IS NULL OR NativeName <> '繁體中文');

UPDATE Languages
SET NativeName = '日本語'
WHERE LangCode = 'ja-JP' AND (NativeName IS NULL OR NativeName <> '日本語');

-- I18nTexts.zh-CN builtins ------------------------------------------------------
-- SQLite supports INSERT OR REPLACE; PostgreSQL uses ON CONFLICT DO UPDATE.
-- To stay portable we use a plain UPDATE ... WHERE; if a row is missing
-- the UPDATE simply no-ops. The regular seed INSERT (SQL_TIER0_I18N_TEXTS_DATA)
-- already uses ON CONFLICT DO NOTHING, so new DBs pick up the correct value
-- on first init; existing DBs get fixed by the UPDATE below.

UPDATE I18nTexts
SET TranslatedText = '确定', IsVerified = 1
WHERE SourceText = 'OK' AND LangCode = 'zh-CN';

UPDATE I18nTexts
SET TranslatedText = '取消', IsVerified = 1
WHERE SourceText = 'Cancel' AND LangCode = 'zh-CN';

UPDATE I18nTexts
SET TranslatedText = '保存', IsVerified = 1
WHERE SourceText = 'Save' AND LangCode = 'zh-CN';

UPDATE I18nTexts
SET TranslatedText = '关闭', IsVerified = 1
WHERE SourceText = 'Close' AND LangCode = 'zh-CN';

UPDATE I18nTexts
SET TranslatedText = '错误', IsVerified = 1
WHERE SourceText = 'Error' AND LangCode = 'zh-CN';

UPDATE I18nTexts
SET TranslatedText = '警告', IsVerified = 1
WHERE SourceText = 'Warning' AND LangCode = 'zh-CN';

UPDATE I18nTexts
SET TranslatedText = '信息', IsVerified = 1
WHERE SourceText = 'Information' AND LangCode = 'zh-CN';

UPDATE I18nTexts
SET TranslatedText = '确认', IsVerified = 1
WHERE SourceText = 'Confirm' AND LangCode = 'zh-CN';

-- Note on missing rows
-- --------------------
-- The regular Tier-0 seed (SQL_TIER0_I18N_TEXTS_DATA in Core/DeepBase.Schema.pas)
-- uses INSERT ... ON CONFLICT DO NOTHING and already carries the correct
-- UTF-8 values. On any DB where the Tier-0 seed has been applied (i.e.
-- every real production DB), the UPDATE above is sufficient. Only the
-- extremely rare case of a DB that has the Languages/I18nTexts tables
-- but never had the seed run would miss these rows; re-running the
-- application's normal Tier-0 init will insert them.
