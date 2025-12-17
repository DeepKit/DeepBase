{ ============================================================================
  UniBase.Interfaces - Core Module Interfaces
  
  Version: 0.3
  Description: Interface definitions for core UniBase modules.
               Enables dependency injection, unit testing with mocks,
               and alternative implementations.
  
  Usage:
    - Modules can implement these interfaces
    - Test code can create mock implementations
    - Application code can depend on interfaces instead of concrete classes
  ============================================================================ }

unit UniBase.Interfaces;

interface

uses
  System.SysUtils,
  System.Classes,
  UniBase.Types;

type
  // ========================================
  // Forward declarations
  // ========================================
  
  IUniBaseConfig = interface;
  IUniBaseLogger = interface;
  IUniBaseI18n = interface;
  IUniBaseMRU = interface;

  // ========================================
  // IUniBaseConfig - Configuration Interface
  // ========================================
  
  /// <summary>
  /// Configuration management interface.
  /// Provides type-safe config read/write with caching.
  /// </summary>
  IUniBaseConfig = interface
    ['{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}']
    
    // String config
    function GetConfig(const Key: string; const Default: string = ''): string;
    procedure SetConfig(const Key, Value: string; const Category: string = 'General');
    
    // Integer config
    function GetConfigInt(const Key: string; Default: Integer = 0): Integer;
    procedure SetConfigInt(const Key: string; Value: Integer; const Category: string = 'General');
    
    // Boolean config
    function GetConfigBool(const Key: string; Default: Boolean = False): Boolean;
    procedure SetConfigBool(const Key: string; Value: Boolean; const Category: string = 'General');
    
    // Float config
    function GetConfigFloat(const Key: string; Default: Double = 0): Double;
    procedure SetConfigFloat(const Key: string; Value: Double; const Category: string = 'General');
    
    // Encrypted config - DEPRECATED for security reasons
    function GetConfigEncrypted(const Key: string; const Default: string = ''): string;
      deprecated 'Use UniBase.Security.LoadSecret() for secure DPAPI encryption';
    procedure SetConfigEncrypted(const Key, Value: string; const Category: string = 'General');
      deprecated 'Use UniBase.Security.SaveSecret() for secure DPAPI encryption';
    
    // Utility
    procedure DeleteConfig(const Key: string);
    function ConfigExists(const Key: string): Boolean;
    procedure ClearCache;
    procedure PreloadCache;
  end;

  // ========================================
  // IUniBaseLogger - Logging Interface
  // ========================================
  
  /// <summary>
  /// Logging interface.
  /// Provides multi-level, thread-safe logging.
  /// </summary>
  IUniBaseLogger = interface
    ['{B2C3D4E5-F6A7-5B6C-9D0E-1F2A3B4C5D6E}']
    
    // Basic logging
    procedure Log(const Msg: string; Level: TLogLevel = llInfo; const Source: string = '');
    
    // Shortcut methods
    procedure Debug(const Msg: string; const Source: string = '');
    procedure Info(const Msg: string; const Source: string = '');
    procedure Warn(const Msg: string; const Source: string = '');
    procedure Error(const Msg: string; const Source: string = '');
    procedure Fatal(const Msg: string; const Source: string = '');
    
    // Exception logging
    procedure LogException(E: Exception; const Msg: string = ''; Level: TLogLevel = llError);
    
    // Level control
    function GetMinLevel: TLogLevel;
    procedure SetMinLevel(Value: TLogLevel);
    property MinLevel: TLogLevel read GetMinLevel write SetMinLevel;
  end;

  // ========================================
  // IUniBaseI18n - Internationalization Interface
  // ========================================
  
  /// <summary>
  /// Internationalization interface.
  /// Provides translation with caching.
  /// </summary>
  IUniBaseI18n = interface
    ['{C3D4E5F6-A7B8-6C7D-0E1F-2A3B4C5D6E7F}']
    
    // Translation
    function Translate(const Text: string): string;
    function TranslateTo(const Text, LangCode: string): string;
    function TranslateFormat(const Text: string; const Args: array of const): string;
    function TranslatePlural(const Singular, Plural: string; Count: Integer): string;
    
    // Language management
    function GetAvailableLanguages: TLanguageInfoArray;
    function GetCurrentLanguage: string;
    procedure SetCurrentLanguage(const Value: string);
    property CurrentLanguage: string read GetCurrentLanguage write SetCurrentLanguage;
    
    // Cache
    procedure ClearCache;
  end;

  // ========================================
  // IUniBaseMRU - Most Recently Used Interface
  // ========================================
  
  /// <summary>
  /// MRU (Most Recently Used) management interface.
  /// </summary>
  IUniBaseMRU = interface
    ['{D4E5F6A7-B8C9-7D8E-1F2A-3B4C5D6E7F8A}']
    
    // Core operations
    procedure AddMRU(const Category, ItemKey: string; const DisplayName: string = ''; IconIndex: Integer = 0);
    function GetMRUList(const Category: string; MaxItems: Integer = 10): TArray<string>;
    function GetMRUItems(const Category: string; MaxItems: Integer = 10): TMRUItemArray;
    
    // Removal
    procedure RemoveMRU(const Category, ItemKey: string);
    procedure ClearMRU(const Category: string);
    function RemoveInvalidMRU(const Category: string = ''): Integer;
    
    // Pinning
    procedure SetPinned(const Category, ItemKey: string; IsPinned: Boolean);
    function IsPinned(const Category, ItemKey: string): Boolean;
    
    // Statistics
    function GetMRUCount(const Category: string): Integer;
  end;

  // ========================================
  // IUniBaseManager - Manager Interface (Optional)
  // ========================================
  
  /// <summary>
  /// Core manager interface.
  /// Provides access to all sub-modules.
  /// </summary>
  IUniBaseManager = interface
    ['{E5F6A7B8-C9D0-8E9F-2A3B-4C5D6E7F8A9B}']
    
    // Initialization
    function Initialize: Boolean;
    procedure Finalize;
    function GetIsInitialized: Boolean;
    property IsInitialized: Boolean read GetIsInitialized;
    
    // Sub-modules
    function GetConfig: IUniBaseConfig;
    function GetLogger: IUniBaseLogger;
    function GetI18n: IUniBaseI18n;
    function GetMRU: IUniBaseMRU;
    
    property Config: IUniBaseConfig read GetConfig;
    property Logger: IUniBaseLogger read GetLogger;
    property I18n: IUniBaseI18n read GetI18n;
    property MRU: IUniBaseMRU read GetMRU;
    
    // Paths
    function GetRootPath: string;
    property RootPath: string read GetRootPath;
  end;

implementation

end.
