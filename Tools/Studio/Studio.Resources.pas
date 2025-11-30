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
begin
  if GCurrentLanguage = 'zh-CN' then
  begin
    // Use direct Chinese strings (avoid encoding issues)
    if Key = 'RSFormCaption' then Result := 'UniBase Studio'
    else if Key = 'RSFormCaptionWithDB' then Result := 'UniBase Studio - %s'
    else if Key = 'RSNoDBOpened' then Result := '未打开数据库'
    else if Key = 'RSLblTitle' then Result := 'UniBase Studio'
    else if Key = 'RSBtnOpen' then Result := '打开数据库...'
    else if Key = 'RSBtnRefresh' then Result := '刷新'
    else if Key = 'RSBtnAdd' then Result := '添加'
    else if Key = 'RSBtnDelete' then Result := '删除'
    else if Key = 'RSMenuSettings' then Result := '设置'
    else if Key = 'RSMenuLogs' then Result := '日志'
    else if Key = 'RSMenuConfiguration' then Result := '配置'
    else if Key = 'RSMenuData' then Result := '数据'
    else if Key = 'RSAddConfigTitle' then Result := '添加配置'
    else if Key = 'RSEnterKey' then Result := '输入键:'
    else if Key = 'RSEnterValue' then Result := '输入值:'
    else if Key = 'RSDeleteConfirm' then Result := '确定删除配置 "%s"?'
    else if Key = 'RSFileNotFound' then Result := '数据库文件未找到: %s'
    else if Key = 'RSOpenDBFailed' then Result := '打开数据库失败: %s'
    else if Key = 'RSStatusReady' then Result := '就绪'
    else if Key = 'RSStatusRefreshed' then Result := '已刷新'
    else if Key = 'RSStatusDatabaseOpened' then Result := '数据库已打开'
    else if Key = 'RSStatusDatabaseClosed' then Result := '数据库已关闭'
    else if Key = 'RSStatusDatabaseLabel' then Result := '数据库: %s'
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
