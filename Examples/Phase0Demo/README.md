# UniBase Phase 0 Demo

This is a demo project for UniBase Phase 0 functionalities.
It demonstrates the core modules:
- **UniBase.Manager**: Initialization and Database connection.
- **UniBase.Config**: Reading and writing configuration.
- **UniBase.i18n**: Language switching and text translation.
- **UniBase.FormState**: Saving and restoring form window state.

## How to Run

1. Open `Phase0Demo.dproj` in Delphi.
2. Build and Run.
3. The application will automatically create `config.db` in the executable directory (or AppData if not writable).

## Features

- **Config**: Change the value in the edit box and click "Save Config". It persists to the database.
- **Language**: Switch language using the dropdown. "Welcome" text will be translated (if translation exists in DB).
  - *Note*: Default DB has 'Welcome' -> '欢迎' for 'zh-CN'.
- **Form State**: Resize or move the window, then close and reopen the app. The window position will be restored.
