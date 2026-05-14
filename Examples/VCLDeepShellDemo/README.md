# VCLDeepShellDemo

Minimal `TDeepMainForm` demo. Use it as the starting template for new VCL
desktop tools built on DeepBase.

## What it shows

- `TDemoMainForm = class(TDeepMainForm)`
- The three downstream override hooks: `RegisterServices`, `RegisterCommands`,
  `RegisterProviders`
- Fake structure / main view / inspector / settings page providers
- Commands registered through the fluent `ShellCommand(...)` builder
- Status manager logging in the bottom area

## What it does NOT need

- Db1 / ConfigDB
- doQry / connection pool
- LLM
- WebView2 / CEF
- Governance

The shell core uses in-memory fallback services so the demo starts with no
external dependencies. Real apps replace those services through
`Services.RegisterService` and add a DB1-backed settings store.

## Build

The demo's units are listed in `VCLDeepShellDemo.dpr` and `VCLDeepShellDemo.dproj`.
Open the project in Delphi 13.1 (BDS 37.0) or build from the command line:

```
call D:\_Progs\02Business\scripts\env\delphi-13.1.bat
cd Examples\VCLDeepShellDemo
msbuild VCLDeepShellDemo.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

The dproj sets `DCC_UnitSearchPath` to `..\..\Core;..\..\Services;..\..\Persistence;..\..\Features;..\..\VCL`, so building from a fresh checkout does not require additional library path setup. The IDE may upgrade the dproj on first open; that upgrade is the intended workflow.

## File layout

```
Examples/VCLDeepShellDemo/
├── VCLDeepShellDemo.dpr   - DPR; initialises DeepBase, runs the form
├── Demo.MainForm.pas      - TDemoMainForm = class(TDeepMainForm)
├── Demo.Services.pas      - fake project service
├── Demo.Commands.pas      - sample commands (run scan, delete, welcome)
├── Demo.Providers.pas     - fake structure / main view / inspector / settings
└── README.md              - this file
```

## Reference

- `docs/70.vcl.DeepShell-总览与AI入口.md`
- `docs/76.vcl.DeepShell-新VCL程序接入指南.md` §10
- `docs/78.vcl.DeepShell-验收清单.md`
