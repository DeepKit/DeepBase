# MultiLanguageDemo

A demonstration project showcasing DeepBase i18n (internationalization) features.

## Features Demonstrated

### 1. Basic Translation - `T()`
The simplest way to translate strings:
```pascal
LabelWelcome.Caption := T('Welcome');
ShowMessage(T('Hello'));
```

### 2. Formatted Translation - `TFmt()`
Translate strings with format arguments:
```pascal
// Pattern: 'Hello, %s! You are %d years old.'
Result := TFmt('Hello, %s! You are %d years old.', ['Alice', 25]);
// English: "Hello, Alice! You are 25 years old."
// Chinese: "你好，Alice！你今年 25 岁�?
// Japanese: "こんにちは、Aliceさん！あなた�?5歳です�?
```

### 3. Plural Forms - `TN()`
Handle singular/plural automatically:
```pascal
Result := TN('%d item', '%d items', Count);
// Count=1: "1 item"
// Count=5: "5 items"
```

### 4. I18n-Aware Controls
Controls that auto-update when language changes:
- `TI18nLabel` - Label with `I18nKey` property
- `TI18nButton` - Button with `I18nKey` property

```pascal
// In DFM:
object I18nButton1: TI18nButton
  Caption = 'Save'
  I18nKey = 'Save'
end
```

### 5. Runtime Language Switching
Change language at runtime - all registered controls update automatically:
```pascal
DeepBase.I18n.CurrentLanguage := 'zh-CN';  // Switch to Chinese
DeepBase.I18n.CurrentLanguage := 'ja-JP';  // Switch to Japanese
```

## Supported Languages

| Code  | Language              |
|-------|----------------------|
| en-US | English              |
| zh-CN | Chinese (Simplified) |
| ja-JP | Japanese             |

## How to Build

1. Open `MultiLanguageDemo.dpr` in Delphi IDE
2. Build and run (F9)

## Project Structure

```
MultiLanguageDemo/
├── MultiLanguageDemo.dpr   # Project file
├── MainForm.pas            # Main form unit
├── MainForm.dfm            # Main form design
└── README.md               # This file
```

## Key DeepBase Units Used

- `DeepBase.Manager` - Core framework manager
- `DeepBase.i18n` - Internationalization engine
- `DeepBase.VCL.I18nControls` - VCL controls with i18n support

## Adding New Languages

To add translations for a new language:

```pascal
// In FormCreate or initialization
DeepBase.I18n.AddTranslation('Hello', 'ko-KR', '안녕하세�?);  // Korean
DeepBase.I18n.AddTranslation('Save', 'ko-KR', '저�?);
// ... add more translations
```

Or load from external translation files (JSON format):
```pascal
DeepBase.I18n.LoadTranslationsFromFile('translations_ko.json');
```

## Screenshots

The demo includes 4 tabs:
1. **Basic T()** - Simple translation demonstration
2. **TFmt()** - Formatted translation with arguments
3. **TN() Plural** - Plural form handling
4. **I18n Controls** - Auto-translating VCL controls
