unit Entity.Customer;

{*******************************************************************************
  CRUD Application Template - Customer Entity
  
  This unit demonstrates how to define an entity class using UniBase ORM
  attributes for database mapping.
  
  Features demonstrated:
  - ORM attribute mapping (Table, Column, PrimaryKey)
  - Index declaration
  - Validation integration
  - Business logic encapsulation
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.Classes,
  UniBase.ORM.Mapping;

type
  /// <summary>
  /// Customer status enumeration
  /// </summary>
  TCustomerStatus = (
    csActive,     // Active customer
    csInactive,   // Inactive customer  
    csSuspended,  // Suspended account
    csDeleted     // Soft deleted
  );

  /// <summary>
  /// Customer entity class with ORM mapping
  /// </summary>
  [Table('Customers')]
  [Index('IX_Customers_Email', 'Email', True)]  // Unique index on email
  [Index('IX_Customers_Name', 'LastName, FirstName')]
  [Index('IX_Customers_Status', 'Status')]
  TCustomer = class
  private
    [PrimaryKey]
    [Column('Id')]
    FId: string;

    [Column('FirstName')]
    FFirstName: string;

    [Column('LastName')]
    FLastName: string;

    [Column('Email')]
    FEmail: string;

    [Column('Phone')]
    FPhone: string;

    [Column('Address')]
    FAddress: string;

    [Column('City')]
    FCity: string;

    [Column('Country')]
    FCountry: string;

    [Column('PostalCode')]
    FPostalCode: string;

    [Column('Status')]
    FStatus: Integer;

    [Column('Notes')]
    FNotes: string;

    [Column('CreatedAt')]
    FCreatedAt: TDateTime;

    [Column('UpdatedAt')]
    FUpdatedAt: TDateTime;

    [Column('CreatedBy')]
    FCreatedBy: string;

    function GetStatusEnum: TCustomerStatus;
    procedure SetStatusEnum(const Value: TCustomerStatus);
    function GetFullName: string;
    function GetDisplayName: string;
  public
    constructor Create; overload;
    constructor Create(const AFirstName, ALastName, AEmail: string); overload;

    /// <summary>
    /// Generate a new unique ID
    /// </summary>
    class function NewId: string;

    /// <summary>
    /// Validate the customer data
    /// </summary>
    /// <returns>True if valid, False otherwise</returns>
    function Validate(out ErrorMessage: string): Boolean;

    /// <summary>
    /// Mark the customer for soft delete
    /// </summary>
    procedure MarkDeleted;

    /// <summary>
    /// Check if customer can be activated
    /// </summary>
    function CanActivate: Boolean;

    // Primary key
    property Id: string read FId write FId;

    // Basic information
    property FirstName: string read FFirstName write FFirstName;
    property LastName: string read FLastName write FLastName;
    property Email: string read FEmail write FEmail;
    property Phone: string read FPhone write FPhone;

    // Address information
    property Address: string read FAddress write FAddress;
    property City: string read FCity write FCity;
    property Country: string read FCountry write FCountry;
    property PostalCode: string read FPostalCode write FPostalCode;

    // Status and notes
    property Status: Integer read FStatus write FStatus;
    property StatusEnum: TCustomerStatus read GetStatusEnum write SetStatusEnum;
    property Notes: string read FNotes write FNotes;

    // Audit fields
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
    property CreatedBy: string read FCreatedBy write FCreatedBy;

    // Computed properties (not mapped to database)
    property FullName: string read GetFullName;
    property DisplayName: string read GetDisplayName;
  end;

  /// <summary>
  /// Customer list helper
  /// </summary>
  TCustomerList = class(TList<TCustomer>)
  public
    /// <summary>
    /// Find customer by ID
    /// </summary>
    function FindById(const AId: string): TCustomer;

    /// <summary>
    /// Find customer by email
    /// </summary>
    function FindByEmail(const AEmail: string): TCustomer;

    /// <summary>
    /// Get customers by status
    /// </summary>
    function FilterByStatus(AStatus: TCustomerStatus): TCustomerList;

    /// <summary>
    /// Free all items and clear the list
    /// </summary>
    procedure FreeAll;
  end;

implementation

uses
  System.Generics.Collections,
  System.RegularExpressions;

{ TCustomer }

constructor TCustomer.Create;
begin
  inherited Create;
  FId := NewId;
  FStatus := Ord(csActive);
  FCreatedAt := Now;
  FUpdatedAt := Now;
end;

constructor TCustomer.Create(const AFirstName, ALastName, AEmail: string);
begin
  Create;
  FFirstName := AFirstName;
  FLastName := ALastName;
  FEmail := AEmail;
end;

class function TCustomer.NewId: string;
begin
  Result := TGUID.NewGuid.ToString;
  // Remove braces and dashes for cleaner IDs
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := LowerCase(Result);
end;

function TCustomer.GetStatusEnum: TCustomerStatus;
begin
  if (FStatus >= Ord(Low(TCustomerStatus))) and 
     (FStatus <= Ord(High(TCustomerStatus))) then
    Result := TCustomerStatus(FStatus)
  else
    Result := csActive;
end;

procedure TCustomer.SetStatusEnum(const Value: TCustomerStatus);
begin
  FStatus := Ord(Value);
  FUpdatedAt := Now;
end;

function TCustomer.GetFullName: string;
begin
  Result := Trim(FFirstName + ' ' + FLastName);
end;

function TCustomer.GetDisplayName: string;
begin
  if FLastName <> '' then
    Result := FLastName + ', ' + FFirstName
  else
    Result := FFirstName;
    
  if Result = '' then
    Result := FEmail;
end;

function TCustomer.Validate(out ErrorMessage: string): Boolean;
const
  EmailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
begin
  Result := False;
  ErrorMessage := '';

  // First name is required
  if Trim(FFirstName) = '' then
  begin
    ErrorMessage := 'First name is required';
    Exit;
  end;

  // Last name is required
  if Trim(FLastName) = '' then
  begin
    ErrorMessage := 'Last name is required';
    Exit;
  end;

  // Email is required and must be valid
  if Trim(FEmail) = '' then
  begin
    ErrorMessage := 'Email is required';
    Exit;
  end;

  if not TRegEx.IsMatch(FEmail, EmailPattern) then
  begin
    ErrorMessage := 'Invalid email format';
    Exit;
  end;

  Result := True;
end;

procedure TCustomer.MarkDeleted;
begin
  FStatus := Ord(csDeleted);
  FUpdatedAt := Now;
end;

function TCustomer.CanActivate: Boolean;
begin
  // Can only activate if not deleted and has valid data
  Result := (StatusEnum <> csDeleted) and 
            (Trim(FEmail) <> '') and
            (Trim(FFirstName) <> '');
end;

{ TCustomerList }

function TCustomerList.FindById(const AId: string): TCustomer;
var
  Customer: TCustomer;
begin
  Result := nil;
  for Customer in Self do
    if SameText(Customer.Id, AId) then
      Exit(Customer);
end;

function TCustomerList.FindByEmail(const AEmail: string): TCustomer;
var
  Customer: TCustomer;
begin
  Result := nil;
  for Customer in Self do
    if SameText(Customer.Email, AEmail) then
      Exit(Customer);
end;

function TCustomerList.FilterByStatus(AStatus: TCustomerStatus): TCustomerList;
var
  Customer: TCustomer;
begin
  Result := TCustomerList.Create;
  for Customer in Self do
    if Customer.StatusEnum = AStatus then
      Result.Add(Customer);
end;

procedure TCustomerList.FreeAll;
var
  Customer: TCustomer;
begin
  for Customer in Self do
    Customer.Free;
  Clear;
end;

end.
