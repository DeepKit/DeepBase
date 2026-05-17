# AutoFix Demo

Minimal VCL sample that demonstrates how to wire `DeepBase.AutoFix` and
`DeepBase.AutoFix.VclHook` into a regular `Application.Initialize` /
`Application.Run` flow.

The form is built programmatically (no `.dfm`) so the sample can be
exercised by a CLI build without an IDE save pass.

## Wiring pattern

```pascal
program AutoFixDemo;
uses
  Vcl.Forms,
  DeepBase.AutoFix,
  {$IFDEF MSWINDOWS} DeepBase.AutoFix.VclHook, {$ENDIF}
  Demo.MainForm in 'Demo.MainForm.pas';
begin
  AutoFix.Install;                  // L2 ExceptProc + scenario init
  {$IFDEF MSWINDOWS}
  TAutoFixVclHook.Install;          // L1 Application.OnException
  {$ENDIF}

  AutoFix.RegisterScenario('smoke', procedure begin end);

  Application.Initialize;
  Application.CreateForm(TDemoMainForm, GMainForm);
  Application.Run;
end.
```

The main form calls `AutoFix.NotifyShellShown` from `DoShow`.

## Behaviour

- Without `--autofix-mode` every `AutoFix.*` call is a cheap no-op and no
  files are written under `autofix-output/`.
- With `--autofix-mode --autofix-scenario=smoke,probe` the registered
  scenarios run after the main form is shown and `health-signal.json`,
  `runtime-errors.jsonl`, `scenario-results.jsonl` and `exit-reason.json`
  are written.

## References

- Spec: `.kiro/specs/autofix-runtime-errors/design.md` §3.5 (facade), §3.7 (VclHook)
- Requirements: 14.1, 14.2, 14.3, 14.4

## Build

The demo is not part of `compile_test.bat`. To verify it builds standalone:

```cmd
cmd /c Examples\AutoFixDemo\build.bat
```

The script loads the Delphi 13.1 environment and runs msbuild for the
`Win64\Debug` target.
