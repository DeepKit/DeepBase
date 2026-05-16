unit uSeedMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Types, System.StrUtils, Vcl.ComCtrls,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, System.IOUtils, Data.DB, Vcl.FileCtrl,
  FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.DApt, FireDAC.UI.Intf, FireDAC.VCLUI.Wait, FireDAC.Comp.UI,
  FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat,
  uAntiTamperPackage;

type
  // 图像文件信息记录
  TImageFileInfo = record
    Key: string;           // 图像键名 (wechat, alipay, btc, usdt, aboutme)
    FilePath: string;      // 图像文件路径
    AddressText: string;   // 地址文本
    Description: string;   // 描述信息
  end;

  TfrmSeedMain = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    pnlCenter: TPanel;
    gbDatabase: TGroupBox;
    edtDbPath: TEdit;
    btnSelectDb: TBitBtn;
    gbConfig: TGroupBox;
    lblEncKey: TLabel;
    lblSalt: TLabel;
    lblKdfIter: TLabel;
    edtEncKey: TEdit;
    edtSalt: TEdit;
    edtKdfIterations: TEdit;
    chkEnableHMAC: TCheckBox;
    chkShowKey: TCheckBox;
    pcMain: TPageControl;
    tsImages: TTabSheet;
    tsTexts: TTabSheet;
    lstImages: TListBox;
    pnlImageButtons: TPanel;
    btnAddImage: TBitBtn;
    btnSelectFolder: TBitBtn;
    btnRemoveImage: TBitBtn;
    btnClearAll: TBitBtn;
    btnLoadFromDb: TBitBtn;
    lblImageCount: TLabel;
    pnlTextEditor: TPanel;
    lblTextHint: TLabel;
    lblCurrentImage: TLabel;
    lblCurrentImageKey: TLabel;
    lblAddressText: TLabel;
    lblDescription: TLabel;
    edtAddressText: TEdit;
    memoDescription: TMemo;
    btnSaveText: TBitBtn;
    cboImageSelect: TComboBox;
    pnlBottom: TPanel;
    btnSeed: TBitBtn;
    btnClose: TBitBtn;
    memoLog: TMemo;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure btnAddImageClick(Sender: TObject);
    procedure btnRemoveImageClick(Sender: TObject);
    procedure btnClearAllClick(Sender: TObject);
    procedure btnSeedClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnSelectDbClick(Sender: TObject);
    procedure btnSelectFolderClick(Sender: TObject);
    procedure chkShowKeyClick(Sender: TObject);
    procedure lstImagesClick(Sender: TObject);
    procedure cboImageSelectChange(Sender: TObject);
    procedure edtAddressTextChange(Sender: TObject);
    procedure memoDescriptionChange(Sender: TObject);
    procedure btnSaveTextClick(Sender: TObject);
    procedure pcMainChange(Sender: TObject);
    procedure btnLoadFromDbClick(Sender: TObject);
  private
    FImageFiles: array of TImageFileInfo;
    FCurrentEditIndex: Integer;  // 当前编辑的图像索引
    FTextModified: Boolean;      // 文本是否已修改
    procedure Log(const Msg: string);
    function ValidateInputs: Boolean;
    function ConnectDatabase: TFDConnection;
    function SeedImage(AConn: TFDConnection; Index: Integer): Boolean;
    procedure UpdateImageCount;
    procedure UpdateSeedButtonState;
    procedure AddImageFile(const AFilePath: string);
    procedure UpdateComboBox;
    procedure LoadImageTextInfo(Index: Integer);
    procedure SaveCurrentTextInfo;
    procedure ClearTextEditor;
    procedure LoadFromDatabase;
    function FindImageIndex(const Key: string): Integer;
  public
    { Public declarations }
  end;

var
  frmSeedMain: TfrmSeedMain;

implementation

{$R *.dfm}

procedure TfrmSeedMain.FormCreate(Sender: TObject);
begin
  SetLength(FImageFiles, 0);
  FCurrentEditIndex := -1;
  FTextModified := False;
  
  Caption := '防篡改播种工具';
  lblTitle.Caption := '图像资源加密播种工具';
  
  // 设置默认数据库路径（当前目录）
  edtDbPath.Text := TPath.Combine(ExtractFilePath(ParamStr(0)), 'data.db');
  
  // 设置默认加密配置（示例值，实际使用时需修改）
  edtEncKey.Text := '';
  edtSalt.Text := '';
  edtKdfIterations.Text := '10000';
  chkEnableHMAC.Checked := True;
  
  btnSeed.Enabled := False;
  ClearTextEditor;
  UpdateImageCount;
  
  Log('播种工具已启动');
  Log('严格模式：将写入 sha256_hash + hmac_sha256 字段');
  Log('重要：请先选择数据库文件并填写加密配置');
  Log('提示：加密配置需与主程序中的配置完全一致！');
  Log('提示：切换到"文字配置"页签可编辑地址和描述信息');
end;

procedure TfrmSeedMain.AddImageFile(const AFilePath: string);
var
  FileName: string;
  I, NewIndex: Integer;
begin
  FileName := TPath.GetFileNameWithoutExtension(AFilePath);
  
  // 检查文件是否已添加
  for I := 0 to High(FImageFiles) do
    if SameText(FImageFiles[I].Key, FileName) then
      Exit;
  
  // 添加新记录
  NewIndex := Length(FImageFiles);
  SetLength(FImageFiles, NewIndex + 1);
  FImageFiles[NewIndex].Key := FileName;
  FImageFiles[NewIndex].FilePath := AFilePath;
  FImageFiles[NewIndex].AddressText := '';
  FImageFiles[NewIndex].Description := '';
  
  lstImages.Items.Add(Format('%s -> %s', [FileName, TPath.GetFileName(AFilePath)]));
  UpdateComboBox;
end;

procedure TfrmSeedMain.UpdateComboBox;
var
  I: Integer;
begin
  cboImageSelect.Clear;
  for I := 0 to High(FImageFiles) do
    cboImageSelect.Items.Add(FImageFiles[I].Key);
end;

procedure TfrmSeedMain.lstImagesClick(Sender: TObject);
begin
  if lstImages.ItemIndex >= 0 then
  begin
    // 保存当前编辑
    if FTextModified then
      SaveCurrentTextInfo;
    
    // 加载选中图像的文本信息
    LoadImageTextInfo(lstImages.ItemIndex);
    cboImageSelect.ItemIndex := lstImages.ItemIndex;
  end;
end;

procedure TfrmSeedMain.cboImageSelectChange(Sender: TObject);
begin
  if cboImageSelect.ItemIndex >= 0 then
  begin
    // 保存当前编辑
    if FTextModified then
      SaveCurrentTextInfo;
    
    LoadImageTextInfo(cboImageSelect.ItemIndex);
    lstImages.ItemIndex := cboImageSelect.ItemIndex;
  end;
end;

procedure TfrmSeedMain.LoadImageTextInfo(Index: Integer);
begin
  if (Index < 0) or (Index > High(FImageFiles)) then
  begin
    ClearTextEditor;
    Exit;
  end;
  
  FCurrentEditIndex := Index;
  lblCurrentImageKey.Caption := FImageFiles[Index].Key;
  edtAddressText.Text := FImageFiles[Index].AddressText;
  memoDescription.Text := FImageFiles[Index].Description;
  FTextModified := False;
  btnSaveText.Enabled := False;
end;

procedure TfrmSeedMain.SaveCurrentTextInfo;
begin
  if (FCurrentEditIndex >= 0) and (FCurrentEditIndex <= High(FImageFiles)) then
  begin
    FImageFiles[FCurrentEditIndex].AddressText := edtAddressText.Text;
    FImageFiles[FCurrentEditIndex].Description := memoDescription.Text;
    FTextModified := False;
    btnSaveText.Enabled := False;
    Log(Format('已保存 %s 的文本配置', [FImageFiles[FCurrentEditIndex].Key]));
  end;
end;

procedure TfrmSeedMain.ClearTextEditor;
begin
  FCurrentEditIndex := -1;
  lblCurrentImageKey.Caption := '未选择';
  edtAddressText.Text := '';
  memoDescription.Text := '';
  FTextModified := False;
  btnSaveText.Enabled := False;
end;

procedure TfrmSeedMain.edtAddressTextChange(Sender: TObject);
begin
  if FCurrentEditIndex >= 0 then
  begin
    FTextModified := True;
    btnSaveText.Enabled := True;
  end;
end;

procedure TfrmSeedMain.memoDescriptionChange(Sender: TObject);
begin
  if FCurrentEditIndex >= 0 then
  begin
    FTextModified := True;
    btnSaveText.Enabled := True;
  end;
end;

procedure TfrmSeedMain.btnSaveTextClick(Sender: TObject);
begin
  SaveCurrentTextInfo;
end;

procedure TfrmSeedMain.pcMainChange(Sender: TObject);
begin
  // 切换到"文字配置"页签时，自动选中第一个图像或当前选中的图像
  if pcMain.ActivePage = tsTexts then
  begin
    if Length(FImageFiles) > 0 then
    begin
      // 如果当前没有选中图像，选中第一个
      if FCurrentEditIndex < 0 then
      begin
        cboImageSelect.ItemIndex := 0;
        LoadImageTextInfo(0);
      end
      else
      begin
        cboImageSelect.ItemIndex := FCurrentEditIndex;
      end;
    end;
  end;
end;

function TfrmSeedMain.FindImageIndex(const Key: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FImageFiles) do
    if SameText(FImageFiles[I].Key, Key) then
    begin
      Result := I;
      Exit;
    end;
end;

procedure TfrmSeedMain.btnLoadFromDbClick(Sender: TObject);
begin
  LoadFromDatabase;
end;

procedure TfrmSeedMain.LoadFromDatabase;
var
  Conn: TFDConnection;
  Query: TFDQuery;
  ImageKey, AddressText, Description: string;
  NewIndex, ExistingIndex: Integer;
begin
  if Trim(edtDbPath.Text) = '' then
  begin
    MessageDlg('请先选择数据库文件！', mtWarning, [mbOK], 0);
    Exit;
  end;
  
  if not TFile.Exists(edtDbPath.Text) then
  begin
    MessageDlg('数据库文件不存在！', mtWarning, [mbOK], 0);
    Exit;
  end;
  
  Conn := nil;
  Query := nil;
  try
    Conn := TFDConnection.Create(nil);
    Conn.DriverName := 'SQLite';
    Conn.Params.Values['Database'] := edtDbPath.Text;
    Conn.LoginPrompt := False;
    Conn.Connected := True;
    
    Query := TFDQuery.Create(nil);
    Query.Connection := Conn;
    Query.SQL.Text := 'SELECT image_key, address_text, description FROM images';
    Query.Open;
    
    if Query.IsEmpty then
    begin
      Log('数据库中没有图像记录');
      MessageDlg('数据库中没有图像记录！', mtInformation, [mbOK], 0);
      Exit;
    end;
    
    Log('开始从数据库加载图像记录...');
    
    while not Query.Eof do
    begin
      ImageKey := Query.FieldByName('image_key').AsString;
      AddressText := Query.FieldByName('address_text').AsString;
      Description := Query.FieldByName('description').AsString;
      
      // 检查是否已存在
      ExistingIndex := FindImageIndex(ImageKey);
      
      if ExistingIndex >= 0 then
      begin
        // 更新现有记录的文本
        FImageFiles[ExistingIndex].AddressText := AddressText;
        FImageFiles[ExistingIndex].Description := Description;
        Log(Format('  更新: %s', [ImageKey]));
      end
      else
      begin
        // 添加新记录（无图像文件，仅文本）
        NewIndex := Length(FImageFiles);
        SetLength(FImageFiles, NewIndex + 1);
        FImageFiles[NewIndex].Key := ImageKey;
        FImageFiles[NewIndex].FilePath := '';  // 无文件路径
        FImageFiles[NewIndex].AddressText := AddressText;
        FImageFiles[NewIndex].Description := Description;
        
        lstImages.Items.Add(Format('%s [仅文本]', [ImageKey]));
        Log(Format('  加载: %s (address=%s)', [ImageKey, IfThen(AddressText <> '', AddressText, '空')]));
      end;
      
      Query.Next;
    end;
    
    UpdateComboBox;
    UpdateImageCount;
    Log(Format('已从数据库加载 %d 条记录', [Query.RecordCount]));
    MessageDlg(Format('已加载 %d 条记录！切换到"文字配置"页签编辑。', [Query.RecordCount]), mtInformation, [mbOK], 0);
    
  except
    on E: Exception do
    begin
      Log('❌ 加载数据库失败: ' + E.Message);
      MessageDlg('加载数据库失败: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  
  if Assigned(Query) then
    Query.Free;
  if Assigned(Conn) then
  begin
    Conn.Connected := False;
    Conn.Free;
  end;
end;

procedure TfrmSeedMain.btnAddImageClick(Sender: TObject);
var
  I: Integer;
begin
  OpenDialog.Filter := '图像文件|*.png;*.jpg;*.jpeg;*.bmp;*.gif|所有文件|*.*';
  OpenDialog.Options := OpenDialog.Options + [ofAllowMultiSelect];
  
  if OpenDialog.Execute then
  begin
    for I := 0 to OpenDialog.Files.Count - 1 do
      AddImageFile(OpenDialog.Files[I]);
    
    UpdateImageCount;
    Log(Format('已添加 %d 个图像文件', [OpenDialog.Files.Count]));
  end;
end;

procedure TfrmSeedMain.btnSelectDbClick(Sender: TObject);
begin
  SaveDialog.FileName := edtDbPath.Text;
  if SaveDialog.Execute then
  begin
    edtDbPath.Text := SaveDialog.FileName;
    Log('数据库路径已更新: ' + SaveDialog.FileName);
    UpdateSeedButtonState;
  end;
end;

procedure TfrmSeedMain.btnSelectFolderClick(Sender: TObject);
var
  SelectedDir: string;
  Files: TStringDynArray;
  I, AddedCount: Integer;
  Ext: string;
begin
  SelectedDir := '';
  if SelectDirectory('选择包含图像的文件夹', '', SelectedDir) then
  begin
    AddedCount := 0;
    Files := TDirectory.GetFiles(SelectedDir);
    for I := 0 to Length(Files) - 1 do
    begin
      Ext := LowerCase(TPath.GetExtension(Files[I]));
      if (Ext = '.png') or (Ext = '.jpg') or (Ext = '.jpeg') or 
         (Ext = '.bmp') or (Ext = '.gif') then
      begin
        AddImageFile(Files[I]);
        Inc(AddedCount);
      end;
    end;
    
    UpdateImageCount;
    Log(Format('从文件夹添加了 %d 个图像文件', [AddedCount]));
  end;
end;

procedure TfrmSeedMain.chkShowKeyClick(Sender: TObject);
begin
  if chkShowKey.Checked then
    edtEncKey.PasswordChar := #0
  else
    edtEncKey.PasswordChar := '*';
end;

procedure TfrmSeedMain.btnRemoveImageClick(Sender: TObject);
var
  Idx, I: Integer;
begin
  Idx := lstImages.ItemIndex;
  if Idx >= 0 then
  begin
    // 从数组中删除
    for I := Idx to High(FImageFiles) - 1 do
      FImageFiles[I] := FImageFiles[I + 1];
    SetLength(FImageFiles, Length(FImageFiles) - 1);
    
    lstImages.Items.Delete(Idx);
    UpdateComboBox;
    
    // 清空编辑器
    if FCurrentEditIndex = Idx then
      ClearTextEditor
    else if FCurrentEditIndex > Idx then
      Dec(FCurrentEditIndex);
    
    UpdateImageCount;
    Log('已移除选中的图像');
  end;
end;

procedure TfrmSeedMain.btnClearAllClick(Sender: TObject);
begin
  if MessageDlg('确定要清空所有图像吗？', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    SetLength(FImageFiles, 0);
    lstImages.Clear;
    cboImageSelect.Clear;
    ClearTextEditor;
    UpdateImageCount;
    Log('已清空所有图像');
  end;
end;

procedure TfrmSeedMain.btnSeedClick(Sender: TObject);
var
  Conn: TFDConnection;
  I, SuccessCount, FailCount: Integer;
  Config: TAntiTamperConfig;
  KdfIter: Integer;
begin
  if not ValidateInputs then
    Exit;
    
  btnSeed.Enabled := False;
  Screen.Cursor := crHourGlass;
  try
    Log('===== 开始播种 =====');
    
    // 解析 KDF 迭代次数
    if not TryStrToInt(Trim(edtKdfIterations.Text), KdfIter) then
      KdfIter := 10000;
    if KdfIter < 1000 then KdfIter := 1000;
    if KdfIter > 100000 then KdfIter := 100000;
    
    // 使用界面输入的参数初始化防篡改包
    Config := TAntiTamperPackage.GetDefaultConfig;
    Config.EncryptionKey := edtEncKey.Text;
    Config.DownloadURL := 'https://www.goodmem.cn';
    Config.EnableLogging := True;
    Config.EncryptionType := etAES256;
    Config.Salt := Trim(edtSalt.Text);
    Config.KdfIterations := KdfIter;
    Config.EnableHMAC := chkEnableHMAC.Checked;
    TAntiTamperPackage.Initialize(Config);
    
    Log(Format('✓ 加密配置:', []));
    Log(Format('  - EncryptionKey 长度: %d', [Length(edtEncKey.Text)]));
    Log(Format('  - Salt: %s', [Config.Salt]));
    Log(Format('  - KdfIterations: %d', [Config.KdfIterations]));
    Log(Format('  - EnableHMAC: %s', [BoolToStr(Config.EnableHMAC, True)]));
    
    // 连接数据库
    Conn := ConnectDatabase;
    if not Assigned(Conn) then
    begin
      Log('❌ 数据库连接失败');
      Exit;
    end;
    
    try
      // 确保表结构
      if not TAntiTamperPackage.SetupDatabase(Conn) then
      begin
        Log('❌ 创建/校验数据表失败');
        Exit;
      end;
      
      Log('✓ 数据库表结构准备完成');
      
      // 播种每个图像
      SuccessCount := 0;
      FailCount := 0;
      for I := 0 to High(FImageFiles) do
      begin
        if SeedImage(Conn, I) then
          Inc(SuccessCount)
        else
          Inc(FailCount);
      end;
      
      Log('===== 播种完成 =====');
      Log(Format('成功：%d，失败：%d', [SuccessCount, FailCount]));
      
      if FailCount = 0 then
        MessageDlg('所有图像播种成功！', mtInformation, [mbOK], 0)
      else
        MessageDlg(Format('播种完成：成功 %d 个，失败 %d 个', [SuccessCount, FailCount]), 
          mtWarning, [mbOK], 0);
          
    finally
      Conn.Free;
    end;
    
  finally
    Screen.Cursor := crDefault;
    btnSeed.Enabled := True;
  end;
end;

procedure TfrmSeedMain.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmSeedMain.Log(const Msg: string);
begin
  memoLog.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss', Now), Msg]));
  Application.ProcessMessages;
end;

function TfrmSeedMain.ValidateInputs: Boolean;
var
  KdfIter: Integer;
begin
  Result := False;
  
  // 验证数据库路径
  if Trim(edtDbPath.Text) = '' then
  begin
    MessageDlg('请选择数据库文件路径！', mtWarning, [mbOK], 0);
    btnSelectDb.SetFocus;
    Exit;
  end;
  
  // 验证加密密钥
  if Trim(edtEncKey.Text) = '' then
  begin
    MessageDlg('请输入加密密钥！', mtWarning, [mbOK], 0);
    edtEncKey.SetFocus;
    Exit;
  end;
  
  if Length(edtEncKey.Text) < 8 then
  begin
    MessageDlg('加密密钥长度不能少于8位！', mtWarning, [mbOK], 0);
    edtEncKey.SetFocus;
    Exit;
  end;
  
  // 验证 Salt
  if Trim(edtSalt.Text) = '' then
  begin
    MessageDlg('请输入 Salt！', mtWarning, [mbOK], 0);
    edtSalt.SetFocus;
    Exit;
  end;
  
  // 验证 KDF 迭代次数
  if not TryStrToInt(Trim(edtKdfIterations.Text), KdfIter) then
  begin
    MessageDlg('KDF 迭代次数必须是数字！', mtWarning, [mbOK], 0);
    edtKdfIterations.SetFocus;
    Exit;
  end;
  
  if (KdfIter < 1000) or (KdfIter > 100000) then
  begin
    MessageDlg('KDF 迭代次数必须在 1000-100000 之间！', mtWarning, [mbOK], 0);
    edtKdfIterations.SetFocus;
    Exit;
  end;
  
  // 验证图像列表
  if Length(FImageFiles) = 0 then
  begin
    MessageDlg('请至少添加一个图像文件！', mtWarning, [mbOK], 0);
    Exit;
  end;
  
  // 保存当前编辑的文本
  if FTextModified then
    SaveCurrentTextInfo;
  
  Result := True;
end;

function TfrmSeedMain.ConnectDatabase: TFDConnection;
var
  DbPath, DbDir: string;
begin
  Result := nil;
  
  DbPath := Trim(edtDbPath.Text);
  
  // 确保目录存在
  DbDir := ExtractFilePath(DbPath);
  if (DbDir <> '') and not TDirectory.Exists(DbDir) then
  begin
    try
      TDirectory.CreateDirectory(DbDir);
      Log('✓ 已创建目录: ' + DbDir);
    except
      on E: Exception do
      begin
        Log('❌ 无法创建目录: ' + E.Message);
        Exit;
      end;
    end;
  end;
  
  try
    Result := TFDConnection.Create(nil);
    Result.DriverName := 'SQLite';
    Result.Params.Values['Database'] := DbPath;
    Result.LoginPrompt := False;
    Result.Connected := True;
    
    Log('✓ 已连接数据库: ' + DbPath);
  except
    on E: Exception do
    begin
      Log('❌ 数据库连接失败: ' + E.Message);
      if Assigned(Result) then
        FreeAndNil(Result);
    end;
  end;
end;

function TfrmSeedMain.SeedImage(AConn: TFDConnection; Index: Integer): Boolean;
var
  ImageData: TBytes;
  ImageKey, ImagePath, AddressText, Description: string;
  MS: TMemoryStream;
  Query: TFDQuery;
begin
  Result := False;
  
  if (Index < 0) or (Index > High(FImageFiles)) then
    Exit;
  
  ImageKey := FImageFiles[Index].Key;
  ImagePath := FImageFiles[Index].FilePath;
  AddressText := FImageFiles[Index].AddressText;
  Description := FImageFiles[Index].Description;
  
  try
    // 检查是否为"仅文本"模式（无图像文件，仅更新文本字段）
    if ImagePath = '' then
    begin
      Log(Format('更新文本: %s', [ImageKey]));
      
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := AConn;
        Query.SQL.Text := 'UPDATE images SET address_text = :addr, description = :desc, updated_at = CURRENT_TIMESTAMP WHERE image_key = :key';
        Query.ParamByName('addr').AsString := AddressText;
        Query.ParamByName('desc').AsString := Description;
        Query.ParamByName('key').AsString := ImageKey;
        Query.ExecSQL;
        
        if Query.RowsAffected > 0 then
        begin
          Log(Format('  ✓ 文本更新成功: %s', [ImageKey]));
          if AddressText <> '' then
            Log(Format('    地址: %s', [AddressText]));
          Result := True;
        end
        else
        begin
          Log(Format('  ❌ 未找到记录: %s', [ImageKey]));
        end;
      finally
        Query.Free;
      end;
      Exit;
    end;
    
    // 完整播种模式（包含图像文件）
    Log(Format('播种图像: %s', [ImageKey]));
    
    // 读取图像文件
    if not TFile.Exists(ImagePath) then
    begin
      Log(Format('  ❌ 文件不存在: %s', [ImagePath]));
      Exit;
    end;
    
    MS := TMemoryStream.Create;
    try
      MS.LoadFromFile(ImagePath);
      SetLength(ImageData, MS.Size);
      MS.Position := 0;
      MS.Read(ImageData[0], MS.Size);
      
      Log(Format('  读取文件: %d 字节', [Length(ImageData)]));
      if AddressText <> '' then
        Log(Format('  地址文本: %s', [AddressText]));
      if Description <> '' then
        Log(Format('  描述: %s', [Copy(Description, 1, 50) + IfThen(Length(Description) > 50, '...', '')]));
      
      // 使用 TAntiTamperPackage.SaveSecureImage 加密并保存
      try
        if TAntiTamperPackage.SaveSecureImage(AConn, ImageKey, ImageData, AddressText, Description) then
        begin
          Log(Format('  ✓ 播种成功: %s', [ImageKey]));
          Result := True;
        end
        else
        begin
          Log(Format('  ❌ 播种失败: %s （SaveSecureImage 返回 False，检查 antitamper_debug.log）', [ImageKey]));
        end;
      except
        on E: Exception do
        begin
          Log(Format('  ❌ SaveSecureImage 抛出异常: %s - %s', [ImageKey, E.Message]));
        end;
      end;
      
    finally
      MS.Free;
    end;
    
  except
    on E: Exception do
    begin
      Log(Format('  ❌ 异常: %s - %s', [ImageKey, E.Message]));
    end;
  end;
end;

procedure TfrmSeedMain.UpdateImageCount;
begin
  lblImageCount.Caption := Format('已添加 %d 个图像', [Length(FImageFiles)]);
  UpdateSeedButtonState;
end;

procedure TfrmSeedMain.UpdateSeedButtonState;
begin
  btnSeed.Enabled := (Length(FImageFiles) > 0) and 
                     (Trim(edtEncKey.Text) <> '') and
                     (Trim(edtDbPath.Text) <> '');
end;

end.
