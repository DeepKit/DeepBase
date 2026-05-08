unit ECommerce.Entities;

{*******************************************************************************
  E-Commerce Application Template - Entity Definitions
  
  Entities:
    - TProduct: Product catalog item
    - TCategory: Product category (hierarchical)
    - TCustomer: Customer profile
    - TOrder: Order header
    - TOrderItem: Order line item
    - TCartItem: Shopping cart item
    - TPaymentInfo: Payment details
    - TShippingAddress: Delivery address
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  DeepBase.ORM.Mapping;

type
  TOrderStatus = (osCreated, osPending, osPaid, osProcessing, osShipped, 
                  osDelivered, osCancelled, osRefunded);
  
  TPaymentMethod = (pmCreditCard, pmDebitCard, pmPayPal, pmBankTransfer, 
                    pmCashOnDelivery, pmCrypto);
  
  TProductStatus = (psActive, psInactive, psOutOfStock, psDiscontinued);

  [Table('Categories')]
  TCategory = class
  private
    FId: Integer;
    FName: string;
    FDescription: string;
    FParentId: Integer;
    FImageUrl: string;
    FSortOrder: Integer;
    FIsActive: Boolean;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('Name')]
    property Name: string read FName write FName;
    
    [Column('Description')]
    property Description: string read FDescription write FDescription;
    
    [Column('ParentId')]
    property ParentId: Integer read FParentId write FParentId;
    
    [Column('ImageUrl')]
    property ImageUrl: string read FImageUrl write FImageUrl;
    
    [Column('SortOrder')]
    property SortOrder: Integer read FSortOrder write FSortOrder;
    
    [Column('IsActive')]
    property IsActive: Boolean read FIsActive write FIsActive;
  end;

  [Table('Products')]
  TProduct = class
  private
    FId: Integer;
    FSku: string;
    FName: string;
    FDescription: string;
    FCategoryId: Integer;
    FPrice: Currency;
    FComparePrice: Currency;
    FCostPrice: Currency;
    FStockQuantity: Integer;
    FLowStockThreshold: Integer;
    FWeight: Double;
    FImageUrl: string;
    FStatus: TProductStatus;
    FIsFeatured: Boolean;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('Sku')]
    [Index]
    property Sku: string read FSku write FSku;
    
    [Column('Name')]
    property Name: string read FName write FName;
    
    [Column('Description')]
    property Description: string read FDescription write FDescription;
    
    [Column('CategoryId')]
    [ForeignKey('Categories', 'Id')]
    property CategoryId: Integer read FCategoryId write FCategoryId;
    
    [Column('Price')]
    property Price: Currency read FPrice write FPrice;
    
    [Column('ComparePrice')]
    property ComparePrice: Currency read FComparePrice write FComparePrice;
    
    [Column('CostPrice')]
    property CostPrice: Currency read FCostPrice write FCostPrice;
    
    [Column('StockQuantity')]
    property StockQuantity: Integer read FStockQuantity write FStockQuantity;
    
    [Column('LowStockThreshold')]
    property LowStockThreshold: Integer read FLowStockThreshold write FLowStockThreshold;
    
    [Column('Weight')]
    property Weight: Double read FWeight write FWeight;
    
    [Column('ImageUrl')]
    property ImageUrl: string read FImageUrl write FImageUrl;
    
    [Column('Status')]
    property Status: TProductStatus read FStatus write FStatus;
    
    [Column('IsFeatured')]
    property IsFeatured: Boolean read FIsFeatured write FIsFeatured;
    
    [Column('CreatedAt')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    
    [Column('UpdatedAt')]
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
    
    function IsInStock: Boolean;
    function IsLowStock: Boolean;
    function DiscountPercent: Double;
  end;

  [Table('Customers')]
  TCustomer = class
  private
    FId: Integer;
    FEmail: string;
    FPasswordHash: string;
    FFirstName: string;
    FLastName: string;
    FPhone: string;
    FIsActive: Boolean;
    FIsVerified: Boolean;
    FCreatedAt: TDateTime;
    FLastLoginAt: TDateTime;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('Email')]
    [Index]
    property Email: string read FEmail write FEmail;
    
    [Column('PasswordHash')]
    property PasswordHash: string read FPasswordHash write FPasswordHash;
    
    [Column('FirstName')]
    property FirstName: string read FFirstName write FFirstName;
    
    [Column('LastName')]
    property LastName: string read FLastName write FLastName;
    
    [Column('Phone')]
    property Phone: string read FPhone write FPhone;
    
    [Column('IsActive')]
    property IsActive: Boolean read FIsActive write FIsActive;
    
    [Column('IsVerified')]
    property IsVerified: Boolean read FIsVerified write FIsVerified;
    
    [Column('CreatedAt')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    
    [Column('LastLoginAt')]
    property LastLoginAt: TDateTime read FLastLoginAt write FLastLoginAt;
    
    function FullName: string;
  end;

  [Table('ShippingAddresses')]
  TShippingAddress = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FLabel: string;
    FRecipientName: string;
    FStreetAddress: string;
    FCity: string;
    FState: string;
    FPostalCode: string;
    FCountry: string;
    FPhone: string;
    FIsDefault: Boolean;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('CustomerId')]
    [ForeignKey('Customers', 'Id')]
    property CustomerId: Integer read FCustomerId write FCustomerId;
    
    [Column('Label')]
    property Label: string read FLabel write FLabel;
    
    [Column('RecipientName')]
    property RecipientName: string read FRecipientName write FRecipientName;
    
    [Column('StreetAddress')]
    property StreetAddress: string read FStreetAddress write FStreetAddress;
    
    [Column('City')]
    property City: string read FCity write FCity;
    
    [Column('State')]
    property State: string read FState write FState;
    
    [Column('PostalCode')]
    property PostalCode: string read FPostalCode write FPostalCode;
    
    [Column('Country')]
    property Country: string read FCountry write FCountry;
    
    [Column('Phone')]
    property Phone: string read FPhone write FPhone;
    
    [Column('IsDefault')]
    property IsDefault: Boolean read FIsDefault write FIsDefault;
    
    function FormatAddress: string;
  end;

  [Table('Orders')]
  TOrder = class
  private
    FId: Integer;
    FOrderNumber: string;
    FCustomerId: Integer;
    FShippingAddressId: Integer;
    FStatus: TOrderStatus;
    FSubtotal: Currency;
    FShippingCost: Currency;
    FTaxAmount: Currency;
    FDiscountAmount: Currency;
    FTotalAmount: Currency;
    FPaymentMethod: TPaymentMethod;
    FPaymentRef: string;
    FNotes: string;
    FCreatedAt: TDateTime;
    FPaidAt: TDateTime;
    FShippedAt: TDateTime;
    FDeliveredAt: TDateTime;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('OrderNumber')]
    [Index]
    property OrderNumber: string read FOrderNumber write FOrderNumber;
    
    [Column('CustomerId')]
    [ForeignKey('Customers', 'Id')]
    property CustomerId: Integer read FCustomerId write FCustomerId;
    
    [Column('ShippingAddressId')]
    [ForeignKey('ShippingAddresses', 'Id')]
    property ShippingAddressId: Integer read FShippingAddressId write FShippingAddressId;
    
    [Column('Status')]
    property Status: TOrderStatus read FStatus write FStatus;
    
    [Column('Subtotal')]
    property Subtotal: Currency read FSubtotal write FSubtotal;
    
    [Column('ShippingCost')]
    property ShippingCost: Currency read FShippingCost write FShippingCost;
    
    [Column('TaxAmount')]
    property TaxAmount: Currency read FTaxAmount write FTaxAmount;
    
    [Column('DiscountAmount')]
    property DiscountAmount: Currency read FDiscountAmount write FDiscountAmount;
    
    [Column('TotalAmount')]
    property TotalAmount: Currency read FTotalAmount write FTotalAmount;
    
    [Column('PaymentMethod')]
    property PaymentMethod: TPaymentMethod read FPaymentMethod write FPaymentMethod;
    
    [Column('PaymentRef')]
    property PaymentRef: string read FPaymentRef write FPaymentRef;
    
    [Column('Notes')]
    property Notes: string read FNotes write FNotes;
    
    [Column('CreatedAt')]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    
    [Column('PaidAt')]
    property PaidAt: TDateTime read FPaidAt write FPaidAt;
    
    [Column('ShippedAt')]
    property ShippedAt: TDateTime read FShippedAt write FShippedAt;
    
    [Column('DeliveredAt')]
    property DeliveredAt: TDateTime read FDeliveredAt write FDeliveredAt;
    
    function StatusText: string;
    function CanCancel: Boolean;
    function CanRefund: Boolean;
  end;

  [Table('OrderItems')]
  TOrderItem = class
  private
    FId: Integer;
    FOrderId: Integer;
    FProductId: Integer;
    FProductName: string;
    FProductSku: string;
    FUnitPrice: Currency;
    FQuantity: Integer;
    FDiscount: Currency;
    FTotalPrice: Currency;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('OrderId')]
    [ForeignKey('Orders', 'Id')]
    property OrderId: Integer read FOrderId write FOrderId;
    
    [Column('ProductId')]
    [ForeignKey('Products', 'Id')]
    property ProductId: Integer read FProductId write FProductId;
    
    [Column('ProductName')]
    property ProductName: string read FProductName write FProductName;
    
    [Column('ProductSku')]
    property ProductSku: string read FProductSku write FProductSku;
    
    [Column('UnitPrice')]
    property UnitPrice: Currency read FUnitPrice write FUnitPrice;
    
    [Column('Quantity')]
    property Quantity: Integer read FQuantity write FQuantity;
    
    [Column('Discount')]
    property Discount: Currency read FDiscount write FDiscount;
    
    [Column('TotalPrice')]
    property TotalPrice: Currency read FTotalPrice write FTotalPrice;
  end;

  [Table('CartItems')]
  TCartItem = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FProductId: Integer;
    FQuantity: Integer;
    FAddedAt: TDateTime;
  public
    [PrimaryKey]
    [Column('Id')]
    property Id: Integer read FId write FId;
    
    [Column('CustomerId')]
    [ForeignKey('Customers', 'Id')]
    property CustomerId: Integer read FCustomerId write FCustomerId;
    
    [Column('ProductId')]
    [ForeignKey('Products', 'Id')]
    property ProductId: Integer read FProductId write FProductId;
    
    [Column('Quantity')]
    property Quantity: Integer read FQuantity write FQuantity;
    
    [Column('AddedAt')]
    property AddedAt: TDateTime read FAddedAt write FAddedAt;
  end;

  TCartItemEx = record
    Item: TCartItem;
    Product: TProduct;
    function LineTotal: Currency;
  end;

implementation

{ TProduct }

function TProduct.IsInStock: Boolean;
begin
  Result := (FStatus = psActive) and (FStockQuantity > 0);
end;

function TProduct.IsLowStock: Boolean;
begin
  Result := (FStockQuantity > 0) and (FStockQuantity <= FLowStockThreshold);
end;

function TProduct.DiscountPercent: Double;
begin
  if (FComparePrice > 0) and (FComparePrice > FPrice) then
    Result := ((FComparePrice - FPrice) / FComparePrice) * 100
  else
    Result := 0;
end;

{ TCustomer }

function TCustomer.FullName: string;
begin
  Result := Trim(FFirstName + ' ' + FLastName);
end;

{ TShippingAddress }

function TShippingAddress.FormatAddress: string;
begin
  Result := FRecipientName + sLineBreak +
            FStreetAddress + sLineBreak +
            FCity + ', ' + FState + ' ' + FPostalCode + sLineBreak +
            FCountry;
end;

{ TOrder }

function TOrder.StatusText: string;
const
  StatusTexts: array[TOrderStatus] of string = (
    'Created', 'Pending', 'Paid', 'Processing', 
    'Shipped', 'Delivered', 'Cancelled', 'Refunded'
  );
begin
  Result := StatusTexts[FStatus];
end;

function TOrder.CanCancel: Boolean;
begin
  Result := FStatus in [osCreated, osPending, osPaid];
end;

function TOrder.CanRefund: Boolean;
begin
  Result := FStatus in [osPaid, osProcessing, osShipped, osDelivered];
end;

{ TCartItemEx }

function TCartItemEx.LineTotal: Currency;
begin
  if Assigned(Product) then
    Result := Product.Price * Item.Quantity
  else
    Result := 0;
end;

end.
