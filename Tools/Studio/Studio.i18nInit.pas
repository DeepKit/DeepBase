{ ============================================================================
  Studio.i18nInit - Studio i18n Initialization
  
  Version: 1.0
  Description: Detects system language and initializes app internationalization
  ============================================================================ }

unit Studio.i18nInit;

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows;

/// <summary>
/// Initialize internationalization settings, detect and set system language
/// </summary>
procedure InitializeI18n;

/// <summary>
/// Get system language code (e.g. 'zh-CN', 'en-US')
/// </summary>
function GetSystemLanguage: string;

implementation

uses
  Studio.Resources;

function GetSystemLanguage: string;
var
  LangID: Integer;
  LangCode: string;
begin
  // Get user default language
  LangID := GetUserDefaultLangID;
  
  // Convert language ID to standard language code
  case LangID of
    $0804: Result := 'zh-CN';  // Chinese (Simplified)
    $0404: Result := 'zh-TW';  // Chinese (Traditional)
    $0409: Result := 'en-US';  // English (US)
    $0809: Result := 'en-GB';  // English (UK)
    $0407: Result := 'de-DE';  // German (Germany)
    $040C: Result := 'fr-FR';  // French (France)
    $0410: Result := 'it-IT';  // Italian
    $0C0A: Result := 'es-ES';  // Spanish
    $0416: Result := 'pt-BR';  // Portuguese (Brazil)
    $0419: Result := 'ru-RU';  // Russian
    $0411: Result := 'ja-JP';  // Japanese
    $0412: Result := 'ko-KR';  // Korean
  else
    Result := 'en-US';  // Default English
  end;
end;

procedure InitializeI18n;
var
  SystemLang: string;
begin
  try
    // Detect system language
    SystemLang := GetSystemLanguage;
    
    // Set application language resource
    TStudioResources.SetLanguage(SystemLang);
    
    // Debug: output execution result
    // OutputDebugString(PChar('i18n initialized: ' + SystemLang));
  except
    on E: Exception do
    begin
      // If initialization fails, default to English
      TStudioResources.SetLanguage('en-US');
    end;
  end;
end;

end.
