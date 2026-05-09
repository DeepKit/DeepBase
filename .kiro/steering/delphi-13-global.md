---
inclusion: always
---

# Delphi 13.1 Global Rules

DeepBase is migrated on Delphi 13.1 Florence.

## Toolchain

- Target BDS path: `D:\Program Files (x86)\Embarcadero\Studio\37.0`.
- Target BDS version: `37.0`.
- Target compiler version: `37.0`.
- Shared environment entrypoint: `D:\_Progs\02Business\scripts\env\delphi-13.1.bat`.
- Project-local build gates must default to BDS 37.0 and may allow `BDS` environment override.
- Keep the 12.3 baseline only as rollback context. Do not add new `23.0`, `Studio\23.0`, or `BDS\23.0` build paths.

## Package Rules

- Runtime package order: Core, Services, Persistence, Features, FMX, VCL.
- Design-time packages must not duplicate runtime-owned units. Put shared units in runtime packages and require those runtime packages from `dcl*` packages.
- Keep BPL, DCP, and DCU outputs under the existing project output layout. Do not write build artifacts into source directories.
- Warning policy: no new warning above the 12.3 baseline unless it is listed in the migration notes or warning whitelist.

## Compatibility Rules

- Use `{$IF CompilerVersion >= 37}` for compiler-version branches. Do not add new `VER340` / `VER350` style branches for Delphi 13.1 work.
- New code must use Unicode `string` and explicit encodings for IO. Do not use `TEncoding.ANSI` for network or file protocols.
- Do not introduce `with` statements.
- Do not introduce production secrets, API keys, DB4 connection strings, or payment credentials into desktop code.
- Desktop code must not directly write DB4 commerce, payment, entitlement, or license tables. Use server HTTP APIs.
- Legacy `UniBase.*` names are migration residue. New code and package files must use `DeepBase.*`.

## Manual Steps

These still require Delphi 13.1 IDE or human verification:

- IDE-open/save `.dproj` upgrades for packages and project groups.
- Design-time package Install and component palette verification.
- DFM/FMX 96 DPI save conversion and visual DPI checks.
- Third-party package installation into the IDE.
