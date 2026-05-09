---
inclusion: always
---

# Delphi 13.1 Syntax Rules

Use Delphi 13.1 syntax for new DeepBase code and for migration sample refactors.

## Preferred Patterns

| Older pattern | Delphi 13.1 pattern |
| --- | --- |
| `if Cond then Value := A else Value := B;` | `Value := if Cond then A else B;` |
| Separate local declaration plus first assignment | Inline local declaration with inferred type where it improves clarity |
| Version symbols such as `VER340` | `CompilerVersion >= 37` |
| Hand-built small string lists | `TArray<string>` or a typed collection |
| Ad hoc ANSI conversion | `TEncoding.UTF8` or a protocol-specific encoding |

## Examples

Before:

```pascal
var
  LMode: string;
begin
  if AEnabled then
    LMode := 'enabled'
  else
    LMode := 'disabled';
end;
```

After:

```pascal
begin
  var LMode := if AEnabled then 'enabled' else 'disabled';
end;
```

Before:

```pascal
{$IFDEF VER340}
  UseOldCompilerPath;
{$ENDIF}
```

After:

```pascal
{$IF CompilerVersion < 37}
  UsePreD13CompilerPath;
{$ENDIF}
```

## Migration Limits

- Do not rewrite large files only for style. Modernize the touched block or the selected sample file.
- Do not reduce readability by forcing inline variables into long or multi-branch routines.
- Keep ownership and lifetime obvious. Do not replace clear `try..finally` cleanup with a new helper unless the helper already exists locally or materially reduces risk.
- Any syntax modernization must pass the package gate that owns the changed unit.
