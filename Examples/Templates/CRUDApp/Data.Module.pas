unit Data.Module;

{*******************************************************************************
  CRUD Application Template - Data Module
  
  This unit demonstrates how to set up a data access layer using DeepBase
  framework features including:
  - DeepBase Manager initialization
  - ORM DbContext usage
  - Repository pattern implementation
  - Connection pool management
  
  Features demonstrated:
  - DeepBase initialization with database
  - ORM context management
  - CRUD operations with ORM
  - Error handling and logging
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  Data.DB,
  Entity.Customer;

type
  /// <summary>
  /// Data module providing database access and ORM functionality
  /// </summary>
  TDataMod = class(TDataModule)
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    FDatabasePath: string;
    FInitialized: Boolean;

    procedure InitializeDatabase;
    procedure CreateCustomersTable;
  public
    /// <summary>
    /// Path to the database file
    /// </summary>
    property DatabasePath: string read FDatabasePath;

    /// <summary>
    /// Whether the database is initialized
    /// </summary>
    property Initialized: Boolean read FInitialized;

    // Customer CRUD operations
    function GetAllCustomers: TObjectList<TCustomer>;
    function GetCustomerById(const AId: string): TCustomer;
    function GetCustomersByStatus(AStatus: TCustomerStatus): TObjectList<TCustomer>;
    function SearchCustomers(const ASearchText: string): TObjectList<TCustomer>;
    
    procedure SaveCustomer(ACustomer: TCustomer);
    procedure DeleteCustomer(const AId: string);
    function CustomerExists(const AId: string): Boolean;
    function EmailExists(const AEmail: string; const AExcludeId: string = ''): Boolean;
    
    function GetCustomerCount: Integer;
    function GetCustomerCountByStatus(AStatus: TCustomerStatus): Integer;
  end;

var
  DataMod: TDataMod;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

uses
  System.IOUtils,
  DeepBase.Manager,
  DeepBase.Logging;

{ TDataMod }

procedure TDataMod.DataModuleCreate(Sender: TObject);
begin
  FInitialized := False;
  
  // Set database path to application directory
  FDatabasePath := TPath.Combine(
    TPath.GetDirectoryName(ParamStr(0)),
    'CRUDApp.db'
  );
  
  InitializeDatabase;
end;

procedure TDataMod.DataModuleDestroy(Sender: TObject);
begin
  // DeepBase cleanup is handled automatically
  if FInitialized then
    DeepBase.Manager.DeepBase.Finalize;
end;

procedure TDataMod.InitializeDatabase;
begin
  try
    // Initialize DeepBase with database
    DeepBase.Manager.DeepBase.InitializeWithDB(FDatabasePath);
    
    // Create application-specific tables
    CreateCustomersTable;
    
    FInitialized := True;
    Log.Info('Database initialized: %s', [FDatabasePath]);
  except
    on E: Exception do
    begin
      Log.Error('Failed to initialize database: %s', [E.Message]);
      raise;
    end;
  end;
end;

procedure TDataMod.CreateCustomersTable;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    
    // Create Customers table if not exists
    Query.SQL.Text := 
      'CREATE TABLE IF NOT EXISTS Customers (' +
      '  Id TEXT PRIMARY KEY,' +
      '  FirstName TEXT NOT NULL,' +
      '  LastName TEXT NOT NULL,' +
      '  Email TEXT NOT NULL UNIQUE,' +
      '  Phone TEXT,' +
      '  Address TEXT,' +
      '  City TEXT,' +
      '  Country TEXT,' +
      '  PostalCode TEXT,' +
      '  Status INTEGER DEFAULT 0,' +
      '  Notes TEXT,' +
      '  CreatedAt TEXT,' +
      '  UpdatedAt TEXT,' +
      '  CreatedBy TEXT' +
      ')';
    Query.ExecSQL;
    
    // Create indexes
    Query.SQL.Text := 
      'CREATE INDEX IF NOT EXISTS IX_Customers_Name ON Customers(LastName, FirstName)';
    Query.ExecSQL;
    
    Query.SQL.Text := 
      'CREATE INDEX IF NOT EXISTS IX_Customers_Status ON Customers(Status)';
    Query.ExecSQL;
    
    Log.Debug('Customers table created/verified');
  finally
    Query.Free;
  end;
end;

function TDataMod.GetAllCustomers: TObjectList<TCustomer>;
var
  Conn: TFDConnection;
  Query: TFDQuery;
  Customer: TCustomer;
begin
  Result := TObjectList<TCustomer>.Create(True);  // Owns objects
  
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 
      'SELECT * FROM Customers WHERE Status <> :DeletedStatus ORDER BY LastName, FirstName';
    Query.ParamByName('DeletedStatus').AsInteger := Ord(csDeleted);
    Query.Open;
    
    while not Query.Eof do
    begin
      Customer := TCustomer.Create;
      Customer.Id := Query.FieldByName('Id').AsString;
      Customer.FirstName := Query.FieldByName('FirstName').AsString;
      Customer.LastName := Query.FieldByName('LastName').AsString;
      Customer.Email := Query.FieldByName('Email').AsString;
      Customer.Phone := Query.FieldByName('Phone').AsString;
      Customer.Address := Query.FieldByName('Address').AsString;
      Customer.City := Query.FieldByName('City').AsString;
      Customer.Country := Query.FieldByName('Country').AsString;
      Customer.PostalCode := Query.FieldByName('PostalCode').AsString;
      Customer.Status := Query.FieldByName('Status').AsInteger;
      Customer.Notes := Query.FieldByName('Notes').AsString;
      Customer.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Customer.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      Customer.CreatedBy := Query.FieldByName('CreatedBy').AsString;
      Result.Add(Customer);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TDataMod.GetCustomerById(const AId: string): TCustomer;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Result := nil;
  
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 'SELECT * FROM Customers WHERE Id = :Id';
    Query.ParamByName('Id').AsString := AId;
    Query.Open;
    
    if not Query.Eof then
    begin
      Result := TCustomer.Create;
      Result.Id := Query.FieldByName('Id').AsString;
      Result.FirstName := Query.FieldByName('FirstName').AsString;
      Result.LastName := Query.FieldByName('LastName').AsString;
      Result.Email := Query.FieldByName('Email').AsString;
      Result.Phone := Query.FieldByName('Phone').AsString;
      Result.Address := Query.FieldByName('Address').AsString;
      Result.City := Query.FieldByName('City').AsString;
      Result.Country := Query.FieldByName('Country').AsString;
      Result.PostalCode := Query.FieldByName('PostalCode').AsString;
      Result.Status := Query.FieldByName('Status').AsInteger;
      Result.Notes := Query.FieldByName('Notes').AsString;
      Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      Result.CreatedBy := Query.FieldByName('CreatedBy').AsString;
    end;
  finally
    Query.Free;
  end;
end;

function TDataMod.GetCustomersByStatus(AStatus: TCustomerStatus): TObjectList<TCustomer>;
var
  Conn: TFDConnection;
  Query: TFDQuery;
  Customer: TCustomer;
begin
  Result := TObjectList<TCustomer>.Create(True);
  
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 
      'SELECT * FROM Customers WHERE Status = :Status ORDER BY LastName, FirstName';
    Query.ParamByName('Status').AsInteger := Ord(AStatus);
    Query.Open;
    
    while not Query.Eof do
    begin
      Customer := TCustomer.Create;
      Customer.Id := Query.FieldByName('Id').AsString;
      Customer.FirstName := Query.FieldByName('FirstName').AsString;
      Customer.LastName := Query.FieldByName('LastName').AsString;
      Customer.Email := Query.FieldByName('Email').AsString;
      Customer.Phone := Query.FieldByName('Phone').AsString;
      Customer.Status := Query.FieldByName('Status').AsInteger;
      Result.Add(Customer);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TDataMod.SearchCustomers(const ASearchText: string): TObjectList<TCustomer>;
var
  Conn: TFDConnection;
  Query: TFDQuery;
  Customer: TCustomer;
  SearchPattern: string;
begin
  Result := TObjectList<TCustomer>.Create(True);
  
  if Trim(ASearchText) = '' then
  begin
    Result.Free;
    Result := GetAllCustomers;
    Exit;
  end;
  
  SearchPattern := '%' + ASearchText + '%';
  
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 
      'SELECT * FROM Customers ' +
      'WHERE Status <> :DeletedStatus ' +
      'AND (FirstName LIKE :Search OR LastName LIKE :Search OR Email LIKE :Search ' +
      'OR City LIKE :Search OR Phone LIKE :Search) ' +
      'ORDER BY LastName, FirstName';
    Query.ParamByName('DeletedStatus').AsInteger := Ord(csDeleted);
    Query.ParamByName('Search').AsString := SearchPattern;
    Query.Open;
    
    while not Query.Eof do
    begin
      Customer := TCustomer.Create;
      Customer.Id := Query.FieldByName('Id').AsString;
      Customer.FirstName := Query.FieldByName('FirstName').AsString;
      Customer.LastName := Query.FieldByName('LastName').AsString;
      Customer.Email := Query.FieldByName('Email').AsString;
      Customer.Phone := Query.FieldByName('Phone').AsString;
      Customer.Address := Query.FieldByName('Address').AsString;
      Customer.City := Query.FieldByName('City').AsString;
      Customer.Country := Query.FieldByName('Country').AsString;
      Customer.PostalCode := Query.FieldByName('PostalCode').AsString;
      Customer.Status := Query.FieldByName('Status').AsInteger;
      Result.Add(Customer);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TDataMod.SaveCustomer(ACustomer: TCustomer);
var
  Conn: TFDConnection;
  Query: TFDQuery;
  IsNew: Boolean;
begin
  IsNew := not CustomerExists(ACustomer.Id);
  ACustomer.UpdatedAt := Now;
  
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    
    if IsNew then
    begin
      Query.SQL.Text := 
        'INSERT INTO Customers (Id, FirstName, LastName, Email, Phone, Address, ' +
        'City, Country, PostalCode, Status, Notes, CreatedAt, UpdatedAt, CreatedBy) ' +
        'VALUES (:Id, :FirstName, :LastName, :Email, :Phone, :Address, ' +
        ':City, :Country, :PostalCode, :Status, :Notes, :CreatedAt, :UpdatedAt, :CreatedBy)';
    end
    else
    begin
      Query.SQL.Text := 
        'UPDATE Customers SET FirstName = :FirstName, LastName = :LastName, ' +
        'Email = :Email, Phone = :Phone, Address = :Address, City = :City, ' +
        'Country = :Country, PostalCode = :PostalCode, Status = :Status, ' +
        'Notes = :Notes, UpdatedAt = :UpdatedAt WHERE Id = :Id';
    end;
    
    Query.ParamByName('Id').AsString := ACustomer.Id;
    Query.ParamByName('FirstName').AsString := ACustomer.FirstName;
    Query.ParamByName('LastName').AsString := ACustomer.LastName;
    Query.ParamByName('Email').AsString := ACustomer.Email;
    Query.ParamByName('Phone').AsString := ACustomer.Phone;
    Query.ParamByName('Address').AsString := ACustomer.Address;
    Query.ParamByName('City').AsString := ACustomer.City;
    Query.ParamByName('Country').AsString := ACustomer.Country;
    Query.ParamByName('PostalCode').AsString := ACustomer.PostalCode;
    Query.ParamByName('Status').AsInteger := ACustomer.Status;
    Query.ParamByName('Notes').AsString := ACustomer.Notes;
    Query.ParamByName('UpdatedAt').AsDateTime := ACustomer.UpdatedAt;
    
    if IsNew then
    begin
      Query.ParamByName('CreatedAt').AsDateTime := ACustomer.CreatedAt;
      Query.ParamByName('CreatedBy').AsString := ACustomer.CreatedBy;
    end;
    
    Query.ExecSQL;
    
    if IsNew then
      Log.Info('Customer created: %s', [ACustomer.DisplayName])
    else
      Log.Info('Customer updated: %s', [ACustomer.DisplayName]);
  finally
    Query.Free;
  end;
end;

procedure TDataMod.DeleteCustomer(const AId: string);
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    // Soft delete by setting status
    Query.SQL.Text := 
      'UPDATE Customers SET Status = :Status, UpdatedAt = :UpdatedAt WHERE Id = :Id';
    Query.ParamByName('Status').AsInteger := Ord(csDeleted);
    Query.ParamByName('UpdatedAt').AsDateTime := Now;
    Query.ParamByName('Id').AsString := AId;
    Query.ExecSQL;
    
    Log.Info('Customer deleted: %s', [AId]);
  finally
    Query.Free;
  end;
end;

function TDataMod.CustomerExists(const AId: string): Boolean;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 'SELECT COUNT(*) FROM Customers WHERE Id = :Id';
    Query.ParamByName('Id').AsString := AId;
    Query.Open;
    Result := Query.Fields[0].AsInteger > 0;
  finally
    Query.Free;
  end;
end;

function TDataMod.EmailExists(const AEmail: string; const AExcludeId: string): Boolean;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    if AExcludeId <> '' then
    begin
      Query.SQL.Text := 
        'SELECT COUNT(*) FROM Customers WHERE Email = :Email AND Id <> :ExcludeId';
      Query.ParamByName('ExcludeId').AsString := AExcludeId;
    end
    else
      Query.SQL.Text := 'SELECT COUNT(*) FROM Customers WHERE Email = :Email';
    Query.ParamByName('Email').AsString := AEmail;
    Query.Open;
    Result := Query.Fields[0].AsInteger > 0;
  finally
    Query.Free;
  end;
end;

function TDataMod.GetCustomerCount: Integer;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 'SELECT COUNT(*) FROM Customers WHERE Status <> :DeletedStatus';
    Query.ParamByName('DeletedStatus').AsInteger := Ord(csDeleted);
    Query.Open;
    Result := Query.Fields[0].AsInteger;
  finally
    Query.Free;
  end;
end;

function TDataMod.GetCustomerCountByStatus(AStatus: TCustomerStatus): Integer;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := DeepBase.Manager.DeepBase.Connection;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Conn;
    Query.SQL.Text := 'SELECT COUNT(*) FROM Customers WHERE Status = :Status';
    Query.ParamByName('Status').AsInteger := Ord(AStatus);
    Query.Open;
    Result := Query.Fields[0].AsInteger;
  finally
    Query.Free;
  end;
end;

end.
