# DeepBase Phase 1 Demo

This demo showcases the new **VCL Controls** and **Manager Features** implemented in Phase 1.

## Key Features

### 1. VCL Config Controls
- **TConfigEdit**: The "Test Config" edit box is automatically bound to `Demo.TestString`. Change it, close the app, and reopen it. The value persists.
- **TConfigCheckBox**: "Auto Save" is bound to `App.AutoSaveDemo`.

### 2. i18n & Theme Controls
- **TLanguageComboBox**: Select a language (e.g., `zh-CN`) to switch the entire UI language instantly.
- **TThemeComboBox**: Select a VCL Style (Theme) to change the application look and feel.
- **TI18nLabel/Button**: All labels and buttons automatically update their text when the language changes.

### 3. Form State Helper
- **TFormStateHelper**: The main form automatically saves its size, position, and window state (Maximized/Normal) and restores it on launch.

### 4. Log List View
- **TLogListView**: The right-side panel shows a high-performance log viewer.
- Click "Add Log" to generate a new log entry.
- The list auto-refreshes (every 2s by default) and supports virtual scrolling for large datasets.

### 5. Windows 11 Mica
- The form attempts to use the Windows 11 Mica effect for a modern background.

## How to Run
1. Open `Phase1Demo.dproj`.
2. Build and Run.
