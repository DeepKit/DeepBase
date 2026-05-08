{ ============================================================================
  DeepBase.Consts - Framework Constants
  
  Version: 1.0.2
  Description: Centralized string constants for the DeepBase framework.
               Eliminates magic strings scattered throughout the codebase.
  
  Naming Convention:
    - SConfigKey*    : Configuration key names (e.g. SConfigKeyLanguage)
    - SConfigCategory* : Configuration categories (e.g. SConfigCategoryGeneral)
    - SDefault*      : Default values (e.g. SDefaultLanguage)
    - SLangCode*     : Language codes (e.g. SLangCodeZhCN)
    - SMRUCategory*  : MRU category names (e.g. SMRUCategoryFile)
    - STable*        : Database table names (e.g. STableSettings)
    - SLogLevel*     : Log level strings (e.g. SLogLevelDebug)
  
  Note: The 'S' prefix follows Delphi convention for string resourcestrings,
        though these are const strings for simplicity.
  ============================================================================ }

unit DeepBase.Consts;

interface

const
  // ========================================
  // Framework Version
  // ========================================

  DeepBase_VERSION_MAJOR = 1;
  DeepBase_VERSION_MINOR = 0;
  DeepBase_VERSION_PATCH = 2;
  DeepBase_VERSION_STRING = '1.0.2';

  // ========================================
  // Configuration Keys
  // ========================================
  
  /// <summary>Language setting key</summary>
  SConfigKeyLanguage = 'App.Language';
  
  /// <summary>Theme setting key</summary>
  SConfigKeyTheme = 'App.Theme';
  
  /// <summary>Debug mode setting key</summary>
  SConfigKeyDebugMode = 'App.DebugMode';
  
  /// <summary>Log level setting key (DEBUG/INFO/WARN/ERROR/FATAL)</summary>
  SConfigKeyLogLevel = 'Log.Level';
  
  /// <summary>Log storage mode key (Database/File/Both)</summary>
  SConfigKeyLogStorageMode = 'Log.StorageMode';
  
  // ========================================
  // Configuration Categories
  // ========================================
  
  /// <summary>General settings category</summary>
  SConfigCategoryGeneral = 'General';
  
  /// <summary>UI settings category</summary>
  SConfigCategoryUI = 'UI';
  
  /// <summary>Logging settings category</summary>
  SConfigCategoryLogging = 'Logging';
  
  /// <summary>Network settings category</summary>
  SConfigCategoryNetwork = 'Network';
  
  // ========================================
  // Default Values
  // ========================================
  
  /// <summary>Default language code</summary>
  SDefaultLanguage = 'en-US';
  
  /// <summary>Default theme name</summary>
  SDefaultTheme = 'Windows11';
  
  /// <summary>Chinese Simplified language code</summary>
  SLangCodeZhCN = 'zh-CN';
  
  /// <summary>English US language code</summary>
  SLangCodeEnUS = 'en-US';
  
  // ========================================
  // MRU Categories
  // ========================================
  
  /// <summary>Recently opened files</summary>
  SMRUCategoryFile = 'File';
  
  /// <summary>Recently opened projects</summary>
  SMRUCategoryProject = 'Project';
  
  /// <summary>Recent commands</summary>
  SMRUCategoryCommand = 'Command';
  
  /// <summary>Recent searches</summary>
  SMRUCategorySearch = 'Search';
  
  // ========================================
  // Database Table Names
  // ========================================
  
  STableSchemaInfo = 'SchemaInfo';
  STableProjectInfo = 'ProjectInfo';
  STableSettings = 'Settings';
  STableFormStates = 'FormStates';
  STableLanguages = 'Languages';
  STableI18nTexts = 'I18nTexts';
  STableLogs = 'Logs';
  STableMRU = 'MRU';
  STableHotkeys = 'Hotkeys';
  STableThemes = 'Themes';
  STableSecrets = 'Secrets';
  
  // ========================================
  // Log Levels as Strings
  // ========================================
  
  SLogLevelDebug = 'DEBUG';
  SLogLevelInfo = 'INFO';
  SLogLevelWarn = 'WARN';
  SLogLevelError = 'ERROR';
  SLogLevelFatal = 'FATAL';

implementation

end.
