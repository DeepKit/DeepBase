{ ============================================================================
  Studio.Resources - Studio Application Resource Strings
  
  Version: 1.0
  Description: Provides all translatable string constants for the application
  ============================================================================ }

unit Studio.Resources;

interface

uses
  System.SysUtils;

const
  // Form captions and labels
  RSFormCaption           = 'UniBase Studio';
  RSFormCaptionWithDB     = 'UniBase Studio - %s';
  RSNoDBOpened            = 'No DB Opened';
  RSLblTitle              = 'UniBase Studio';
  
  // Button labels
  RSBtnOpen               = 'Open Database...';
  RSBtnRefresh            = 'Refresh';
  RSBtnAdd                = 'Add Key';
  RSBtnDelete             = 'Delete';
  RSBtnOpenOK             = '&Open';
  RSBtnCancel             = '&Cancel';
  
  // Menu items
  RSMenuSettings          = 'Settings';
  RSMenuLogs              = 'Logs';
  RSMenuConfiguration     = 'Configuration';
  RSMenuData              = 'Data';
  RSMenuHotkeys           = 'Hotkeys';
  RSMenuThemes            = 'Themes';
  RSMenuSQLQuery          = 'SQL Query';
  RSMenuQueries           = 'Queries';
  RSMenuSchema            = 'Schema';
  RSMenuBackup            = 'Backup';
  RSMenuImportExport      = 'Import/Export';
  RSMenuProfiler          = 'Profiler';
  RSMenuLLM               = 'LLM Manager';
  RSMenuPromptTemplates   = 'Prompt Templates';
  RSMenuAI                = 'AI / LLM';
  
  // Dialog messages
  RSAddConfigTitle        = 'Add Config';
  RSEnterKey              = 'Enter Key:';
  RSEnterValue            = 'Enter Value:';
  RSDeleteConfirm         = 'Delete config "%s"?';
  RSFileNotFound          = 'Database file not found: %s';
  RSOpenDBFailed          = 'Failed to open database: %s';
  RSOpenDBFilter          = 'SQLite Database (*.db)|*.db|All Files (*.*)|*.*';
  RSOpenDBTitle           = 'Open UniBase Database';
  
  // Status bar messages
  RSStatusReady           = 'Ready';
  RSStatusRefreshed       = 'Refreshed';
  RSStatusDatabaseOpened  = 'Database opened';
  RSStatusDatabaseClosed  = 'Database closed';
  RSStatusDatabaseLabel   = 'Database: %s';

// Chinese translation mappings
type
  TStudioResources = class
  public
    class function GetString(const Key: string): string; static;
    class procedure SetLanguage(const LangCode: string); static;
  end;

implementation

var
  GCurrentLanguage: string = 'en-US';

class function TStudioResources.GetString(const Key: string): string;

  // Helper: Build Chinese strings using WideChar to avoid encoding issues
  function ZH_NoDBOpened: string;
  begin
    // 未打开数据库
    Result := WideChar($672A) + WideChar($6253) + WideChar($5F00) + 
              WideChar($6570) + WideChar($636E) + WideChar($5E93);
  end;
  
  function ZH_OpenDB: string;
  begin
    // 打开数据库...
    Result := WideChar($6253) + WideChar($5F00) + WideChar($6570) + 
              WideChar($636E) + WideChar($5E93) + '...';
  end;
  
  function ZH_Refresh: string;
  begin
    Result := WideChar($5237) + WideChar($65B0); // 刷新
  end;
  
  function ZH_Add: string;
  begin
    Result := WideChar($6DFB) + WideChar($52A0); // 添加
  end;
  
  function ZH_Delete: string;
  begin
    Result := WideChar($5220) + WideChar($9664); // 删除
  end;
  
  function ZH_Settings: string;
  begin
    Result := WideChar($8BBE) + WideChar($7F6E); // 设置
  end;
  
  function ZH_Logs: string;
  begin
    Result := WideChar($65E5) + WideChar($5FD7); // 日志
  end;
  
  function ZH_Config: string;
  begin
    Result := WideChar($914D) + WideChar($7F6E); // 配置
  end;
  
  function ZH_Data: string;
  begin
    Result := WideChar($6570) + WideChar($636E); // 数据
  end;
  
  function ZH_Hotkeys: string;
  begin
    Result := WideChar($5FEB) + WideChar($6377) + WideChar($952E); // 快捷键
  end;
  
  function ZH_Themes: string;
  begin
    Result := WideChar($4E3B) + WideChar($9898); // 主题
  end;
  
  function ZH_SQLQuery: string;
  begin
    Result := 'SQL ' + WideChar($67E5) + WideChar($8BE2); // SQL 查询
  end;
  
  function ZH_Queries: string;
  begin
    // 查询定义
    Result := WideChar($67E5) + WideChar($8BE2) + WideChar($5B9A) + WideChar($4E49);
  end;
  
  function ZH_Schema: string;
  begin
    // 数据结构
    Result := WideChar($6570) + WideChar($636E) + WideChar($7ED3) + WideChar($6784);
  end;
  
  function ZH_Backup: string;
  begin
    Result := WideChar($5907) + WideChar($4EFD); // 备份
  end;
  
  function ZH_ImportExport: string;
  begin
    // 导入/导出
    Result := WideChar($5BFC) + WideChar($5165) + '/' + WideChar($5BFC) + WideChar($51FA);
  end;
  
  function ZH_Profiler: string;
  begin
    // 性能分析
    Result := WideChar($6027) + WideChar($80FD) + WideChar($5206) + WideChar($6790);
  end;
  
  function ZH_LLM: string;
  begin
    Result := 'LLM ' + WideChar($7BA1) + WideChar($7406); // LLM 管理
  end;
  
  function ZH_PromptTemplates: string;
  begin
    // 提示词模板
    Result := WideChar($63D0) + WideChar($793A) + WideChar($8BCD) + WideChar($6A21) + WideChar($677F);
  end;
  
  function ZH_AddConfig: string;
  begin
    // 添加配置
    Result := WideChar($6DFB) + WideChar($52A0) + WideChar($914D) + WideChar($7F6E);
  end;
  
  function ZH_EnterKey: string;
  begin
    // 输入键:
    Result := WideChar($8F93) + WideChar($5165) + WideChar($952E) + ':';
  end;
  
  function ZH_EnterValue: string;
  begin
    // 输入值:
    Result := WideChar($8F93) + WideChar($5165) + WideChar($503C) + ':';
  end;
  
  function ZH_DeleteConfirm: string;
  begin
    // 确定删除配置 "%s"?
    Result := WideChar($786E) + WideChar($5B9A) + WideChar($5220) + WideChar($9664) + 
              WideChar($914D) + WideChar($7F6E) + ' "%s"?';
  end;
  
  function ZH_FileNotFound: string;
  begin
    // 数据库文件未找到: %s
    Result := WideChar($6570) + WideChar($636E) + WideChar($5E93) + WideChar($6587) + 
              WideChar($4EF6) + WideChar($672A) + WideChar($627E) + WideChar($5230) + ': %s';
  end;
  
  function ZH_OpenDBFailed: string;
  begin
    // 打开数据库失败: %s
    Result := WideChar($6253) + WideChar($5F00) + WideChar($6570) + WideChar($636E) + 
              WideChar($5E93) + WideChar($5931) + WideChar($8D25) + ': %s';
  end;
  
  function ZH_Ready: string;
  begin
    Result := WideChar($5C31) + WideChar($7EEA); // 就绪
  end;
  
  function ZH_Refreshed: string;
  begin
    // 已刷新
    Result := WideChar($5DF2) + WideChar($5237) + WideChar($65B0);
  end;
  
  function ZH_DBOpened: string;
  begin
    // 数据库已打开
    Result := WideChar($6570) + WideChar($636E) + WideChar($5E93) + WideChar($5DF2) + 
              WideChar($6253) + WideChar($5F00);
  end;
  
  function ZH_DBClosed: string;
  begin
    // 数据库已关闭
    Result := WideChar($6570) + WideChar($636E) + WideChar($5E93) + WideChar($5DF2) + 
              WideChar($5173) + WideChar($95ED);
  end;
  
  function ZH_DBLabel: string;
  begin
    // 数据库: %s
    Result := WideChar($6570) + WideChar($636E) + WideChar($5E93) + ': %s';
  end;
  
begin
  if GCurrentLanguage = 'zh-CN' then
  begin
    // Use WideChar functions to build Chinese strings
    if Key = 'RSFormCaption' then Result := 'UniBase Studio'
    else if Key = 'RSFormCaptionWithDB' then Result := 'UniBase Studio - %s'
    else if Key = 'RSNoDBOpened' then Result := ZH_NoDBOpened
    else if Key = 'RSLblTitle' then Result := 'UniBase Studio'
    else if Key = 'RSBtnOpen' then Result := ZH_OpenDB
    else if Key = 'RSBtnRefresh' then Result := ZH_Refresh
    else if Key = 'RSBtnAdd' then Result := ZH_Add
    else if Key = 'RSBtnDelete' then Result := ZH_Delete
    else if Key = 'RSMenuSettings' then Result := ZH_Settings
    else if Key = 'RSMenuLogs' then Result := ZH_Logs
    else if Key = 'RSMenuConfiguration' then Result := ZH_Config
    else if Key = 'RSMenuData' then Result := ZH_Data
    else if Key = 'RSMenuHotkeys' then Result := ZH_Hotkeys
    else if Key = 'RSMenuThemes' then Result := ZH_Themes
    else if Key = 'RSMenuSQLQuery' then Result := ZH_SQLQuery
    else if Key = 'RSMenuQueries' then Result := ZH_Queries
    else if Key = 'RSMenuSchema' then Result := ZH_Schema
    else if Key = 'RSMenuBackup' then Result := ZH_Backup
    else if Key = 'RSMenuImportExport' then Result := ZH_ImportExport
    else if Key = 'RSMenuProfiler' then Result := ZH_Profiler
    else if Key = 'RSMenuLLM' then Result := ZH_LLM
    else if Key = 'RSMenuPromptTemplates' then Result := ZH_PromptTemplates
    else if Key = 'RSMenuAI' then Result := 'AI / LLM'
    else if Key = 'RSAddConfigTitle' then Result := ZH_AddConfig
    else if Key = 'RSEnterKey' then Result := ZH_EnterKey
    else if Key = 'RSEnterValue' then Result := ZH_EnterValue
    else if Key = 'RSDeleteConfirm' then Result := ZH_DeleteConfirm
    else if Key = 'RSFileNotFound' then Result := ZH_FileNotFound
    else if Key = 'RSOpenDBFailed' then Result := ZH_OpenDBFailed
    else if Key = 'RSStatusReady' then Result := ZH_Ready
    else if Key = 'RSStatusRefreshed' then Result := ZH_Refreshed
    else if Key = 'RSStatusDatabaseOpened' then Result := ZH_DBOpened
    else if Key = 'RSStatusDatabaseClosed' then Result := ZH_DBClosed
    else if Key = 'RSStatusDatabaseLabel' then Result := ZH_DBLabel
    else Result := Key;
  end
  else
  begin
    if Key = 'RSFormCaption' then Result := 'UniBase Studio'
    else if Key = 'RSFormCaptionWithDB' then Result := 'UniBase Studio - %s'
    else if Key = 'RSNoDBOpened' then Result := 'No DB Opened'
    else if Key = 'RSLblTitle' then Result := 'UniBase Studio'
    else if Key = 'RSBtnOpen' then Result := 'Open Database...'
    else if Key = 'RSBtnRefresh' then Result := 'Refresh'
    else if Key = 'RSBtnAdd' then Result := 'Add Key'
    else if Key = 'RSBtnDelete' then Result := 'Delete'
    else if Key = 'RSMenuSettings' then Result := 'Settings'
    else if Key = 'RSMenuLogs' then Result := 'Logs'
    else if Key = 'RSMenuConfiguration' then Result := 'Configuration'
    else if Key = 'RSMenuData' then Result := 'Data'
    else if Key = 'RSMenuHotkeys' then Result := 'Hotkeys'
    else if Key = 'RSMenuThemes' then Result := 'Themes'
    else if Key = 'RSMenuSQLQuery' then Result := 'SQL Query'
    else if Key = 'RSMenuSchema' then Result := 'Schema'
    else if Key = 'RSMenuBackup' then Result := 'Backup'
    else if Key = 'RSMenuImportExport' then Result := 'Import/Export'
    else if Key = 'RSMenuProfiler' then Result := 'Profiler'
    else if Key = 'RSMenuLLM' then Result := 'LLM Manager'
    else if Key = 'RSMenuPromptTemplates' then Result := 'Prompt Templates'
    else if Key = 'RSMenuAI' then Result := 'AI / LLM'
    else if Key = 'RSAddConfigTitle' then Result := 'Add Config'
    else if Key = 'RSEnterKey' then Result := 'Enter Key:'
    else if Key = 'RSEnterValue' then Result := 'Enter Value:'
    else if Key = 'RSDeleteConfirm' then Result := 'Delete config "%s"?'
    else if Key = 'RSFileNotFound' then Result := 'Database file not found: %s'
    else if Key = 'RSOpenDBFailed' then Result := 'Failed to open database: %s'
    else if Key = 'RSStatusReady' then Result := 'Ready'
    else if Key = 'RSStatusRefreshed' then Result := 'Refreshed'
    else if Key = 'RSStatusDatabaseOpened' then Result := 'Database opened'
    else if Key = 'RSStatusDatabaseClosed' then Result := 'Database closed'
    else if Key = 'RSStatusDatabaseLabel' then Result := 'Database: %s'
    else Result := Key;
  end;
end;

class procedure TStudioResources.SetLanguage(const LangCode: string);
begin
  GCurrentLanguage := LangCode;
end;

end.
