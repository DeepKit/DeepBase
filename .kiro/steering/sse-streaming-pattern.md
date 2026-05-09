---
inclusion: fileMatch
fileMatch: "**/LLM*.pas,**/Stream*.pas"
---

# SSE Streaming Pattern

Apply these rules when editing LLM or streaming units during the Delphi 13.1 migration.

## Preferred Direction

- Prefer Delphi 13.1 `System.Net.HttpClient` / `TNetHttpClient` streaming support when it is available in the installed toolchain.
- Keep a transport abstraction boundary so tests can use fake transports and do not depend on external services.
- Do not duplicate SSE parsing logic across Core and Features. Centralize it or clearly mark old Core code as legacy.

## Compatibility Pattern

- Requests for SSE must set `Accept: text/event-stream`.
- Parsers must handle:
  - `data:` lines
  - empty-line event delimiters
  - `[DONE]` terminators used by OpenAI-compatible APIs
  - partial chunks split across transport reads
  - UTF-8 payloads
- Stream callbacks must support cancellation and must not block the UI thread.
- Errors should fail closed with provider/model/request context, but must not log API keys or full secrets.

## Migration Rule

- For Delphi 13.1 native SSE replacement, first add or reuse a fake transport test that proves token ordering, cancellation, and final usage data.
- If the native API cannot be used yet, keep the current parser behind the transport interface and record the reason in `docs/d13-migration-notes.md`.
