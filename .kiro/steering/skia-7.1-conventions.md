---
inclusion: fileMatch
fileMatch: "**/*Skia*.pas,**/FMX/*.pas"
---

# Skia 7.1 Conventions

Apply these rules when editing Skia-related or FMX rendering code during the Delphi 13.1 migration.

## Version Target

- Target Skia4Delphi version: `7.1.0`.
- Confirm installed IDE paths before adding package search paths.
- Do not add hard-coded Delphi 12.3 or BDS 23.0 Skia paths.

## Unit And API Rules

- Prefer the Skia4Delphi 7.1 unit layout installed for Delphi 13.1.
- Do not introduce legacy `VCL.Skia.*` or `FMX.Skia.*` unit paths unless the installed 7.1 package explicitly provides them.
- Keep Skia-specific code inside VCL/FMX layers or dedicated rendering helpers. Core must stay UI-neutral.
- Prefer encoded-image APIs for SVG/vector/raster resources instead of loading vector assets through `TBitmap.LoadFromFile`.
- Avoid hand-calculated DPI scaling in new rendering code. Use 96 DPI DFM/FMX saves and framework scaling hooks.

## Verification

- If a Skia unit path changes, update package search paths and record the old/new mapping in `docs/d13-migration-notes.md`.
- Build both the owning runtime package and any design-time package that exposes the component.
- Visual rendering checks still require the Delphi 13.1 IDE or an executable smoke test.
