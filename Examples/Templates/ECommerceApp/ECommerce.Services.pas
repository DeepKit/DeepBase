unit ECommerce.Services;

{*******************************************************************************
  E-Commerce Application Template - Business Services
  
  Services:
    - TProductService: Product catalog management
    - TCartService: Shopping cart operations
    - TOrderService: Order processing
    - TCustomerService: Customer management
    - TInventoryService: Stock management
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client,
  ECommerce.Entities,
  UniBase.ORM,
  UniBase.Exceptions;

type
  TProductFilter = record
    CategoryId: Integer;
    MinPrice: Currency;
    MaxPrice: Currency;
    InStockOnly: Boolean;
    SearchText: string;
    SortBy: string;
    SortDesc: Boolean;
    Page: Integer;
    PageSize: Integer;
    
    class function Default: TProductFilter; static;
  end;

  TProductSearchResult = record
    Products: TObjectList<TProduct>;
    TotalCount: Integer;
    PageCount: Integer;
  end;

  TOrderFilter = record
    CustomerId: Integer;
    Status: TOrderStatus;
    DateFrom: TDateTime;
    DateTo: TDateTime;
    HasStatus: Boolean;
    
    class function Default: TProductFilter; static;
  end;

  TProductService = class
  private
    FContext: TDbContext;
  public
    constructor Create(AContext: TDbContext);
    
    function GetById(AId: Integer): TProduct;
    function GetBySku(const ASku: string): TProduct;
    function GetAll: TObjectList<TProduct>;
    function Search(const AFilter: TProductFilter): TProductSearchResult;
    function GetFeatured(ALimit: Integer = 10): TObjectList<TProduct>;
    function GetByCategory(ACategoryId: Integer): TObjectList<TProduct>;
    function GetRelated(AProductId: Integer; ALimit: Integer = 5): TObjectList<TProduct>;
    
    procedure Add(AProduct: TProduct);
    procedure Update(AProduct: TProduct);
    procedure Delete(AId: Integer);
    
    procedure UpdateStock(AProductId: Integer; AQuantity: Integer);
    procedure DeductStock(AProductId: Integer; AQuantity: Integer);
    function CheckStock(AProductId: Integer; AQuantity: Integer): Boolean;
  end;

  TCategoryService = class
  private
    FContext: TDbContext;
  public
    constructor Create(AContext: TDbContext);
    
    function GetAll: TObjectList<TCategory>;
    function GetById(AId: Integer): TCategory;
    function GetChildren(AParentId: Integer): TObjectList<TCategory>;
    function GetRootCategories: TObjectList<TCategory>;
    function GetBreadcrumb(ACategoryId: Integer): TArray<TCategory>;
    
    procedure Add(ACategory: TCategory);
    procedure Update(ACategory: TCategory);
    procedure Delete(AId: Integer);
  end;

  TCartService = class
  private
    FContext: TDbContext;
    FProductService: TProductService;
  public
    constructor Create(AContext: TDbContext; AProductService: TProductService);
    
    function GetCart(ACustomerId: Integer): TObjectList<TCartItem>;
    function GetCartWithProducts(ACustomerId: Integer): TArray<TCartItemEx>;
    function GetCartTotal(ACustomerId: Integer): Currency;
    function GetCartItemCount(ACustomerId: Integer): Integer;
    
    procedure AddToCart(ACustomerId, AProductId: Integer; AQuantity: Integer = 1);
    procedure UpdateQuantity(ACustomerId, AProductId: Integer; AQuantity: Integer);
    procedure RemoveFromCart(ACustomerId, AProductId: Integer);
    procedure ClearCart(ACustomerId: Integer);
    
    function ValidateCart(ACustomerId: Integer; out AErrors: TArray<string>): Boolean;
  end;

  TOrderService = class
  private
    FContext: TDbContext;
    FProductService: TProductService;
    FCartService: TCartService;
    
    function GenerateOrderNumber: string;
    procedure CreateOrderItems(AOrderId, ACustomerId: Integer);
  public
    constructor Create(AContext: TDbContext; AProductService: TProductService;
      ACartService: TCartService);
    
    function GetById(AId: Integer): TOrder;
    function GetByOrderNumber(const AOrderNumber: string): TOrder;
    function GetByCustomer(ACustomerId: Integer): TObjectList<TOrder>;
    function GetOrderItems(AOrderId: Integer): TObjectList<TOrderItem>;
    function GetRecentOrders(ALimit: Integer = 20): TObjectList<TOrder>;
    
    function CreateOrder(ACustomerId, AShippingAddressId: Integer;
      APaymentMethod: TPaymentMethod; const ANotes: string = ''): TOrder;
    
    procedure UpdateStatus(AOrderId: Integer; AStatus: TOrderStatus);
    procedure MarkAsPaid(AOrderId: Integer; const APaymentRef: string);
    procedure MarkAsShipped(AOrderId: Integer; const ATrackingNumber: string);
    procedure CancelOrder(AOrderId: Integer; const AReason: string);
    procedure RefundOrder(AOrderId: Integer; const AReason: string);
    
    function CalculateSubtotal(ACustomerId: Integer): Currency;
    function CalculateShipping(ACustomerId: Integer; AAddressId: Integer): Currency;
    function CalculateTax(ASubtotal: Currency): Currency;
  end;

  TCustomerService = class
  private
    FContext: TDbContext;
    function HashPassword(const APassword: string): string;
    function VerifyPassword(const APassword, AHash: string): Boolean;
  public
    constructor Create(AContext: TDbContext);
    
    function GetById(AId: Integer): TCustomer;
    function GetByEmail(const AEmail: string): TCustomer;
    function Authenticate(const AEmail, APassword: string): TCustomer;
    
    function Register(const AEmail, APassword, AFirstName, ALastName: string): TCustomer;
    procedure Update(ACustomer: TCustomer);
    procedure ChangePassword(ACustomerId: Integer; const AOldPassword, ANewPassword: string);
    procedure ResetPassword(const AEmail: string);
    
    function GetAddresses(ACustomerId: Integer): TObjectList<TShippingAddress>;
    function GetDefaultAddress(ACustomerId: Integer): TShippingAddress;
    procedure AddAddress(AAddress: TShippingAddress);
    procedure UpdateAddress(AAddress: TShippingAddress);
    procedure DeleteAddress(AAddressId: Integer);
    procedure SetDefaultAddress(ACustomerId, AAddressId: Integer);
  end;

  TInventoryService = class
  private
    FContext: TDbContext;
  public
    constructor Create(AContext: TDbContext);
    
    function GetLowStockProducts: TObjectList<TProduct>;
    function GetOutOfStockProducts: TObjectList<TProduct>;
    
    procedure AdjustStock(AProductId: Integer; AQuantityChange: Integer; 
      const AReason: string);
    procedure SetStock(AProductId: Integer; AQuantity: Integer;
      const AReason: string);
    
    function GetStockValue: Currency;
    function GetStockCount: Integer;
  end;

implementation

uses
  System.DateUtils, System.Hash;

{ TProductFilter }

class function TProductFilter.Default: TProductFilter;
begin
  Result.CategoryId := 0;
  Result.MinPrice := 0;
  Result.MaxPrice := 0;
  Result.InStockOnly := False;
  Result.SearchText := '';
  Result.SortBy := 'Name';
  Result.SortDesc := False;
  Result.Page := 1;
  Result.PageSize := 20;
end;

{ TProductService }

constructor TProductService.Create(AContext: TDbContext);
begin
  FContext := AContext;
end;

function TProductService.GetById(AId: Integer): TProduct;
begin
  Result := FContext.Find<TProduct>(AId);
end;

function TProductService.GetBySku(const ASku: string): TProduct;
begin
  Result := FContext.Query<TProduct>
    .Where('Sku = :sku', [ASku])
    .FirstOrDefault;
end;

function TProductService.GetAll: TObjectList<TProduct>;
begin
  Result := FContext.Query<TProduct>
    .Where('Status <> :status', [Ord(psDiscontinued)])
    .OrderBy('Name')
    .ToList;
end;

function TProductService.Search(const AFilter: TProductFilter): TProductSearchResult;
var
  Query: TQueryBuilder<TProduct>;
  CountQuery: TQueryBuilder<TProduct>;
begin
  Query := FContext.Query<TProduct>;
  CountQuery := FContext.Query<TProduct>;
  
  // Category filter
  if AFilter.CategoryId > 0 then
  begin
    Query.Where('CategoryId = :catId', [AFilter.CategoryId]);
    CountQuery.Where('CategoryId = :catId', [AFilter.CategoryId]);
  end;
  
  // Price range
  if AFilter.MinPrice > 0 then
  begin
    Query.Where('Price >= :minPrice', [AFilter.MinPrice]);
    CountQuery.Where('Price >= :minPrice', [AFilter.MinPrice]);
  end;
  
  if AFilter.MaxPrice > 0 then
  begin
    Query.Where('Price <= :maxPrice', [AFilter.MaxPrice]);
    CountQuery.Where('Price <= :maxPrice', [AFilter.MaxPrice]);
  end;
  
  // Stock filter
  if AFilter.InStockOnly then
  begin
    Query.Where('StockQuantity > 0 AND Status = :active', [Ord(psActive)]);
    CountQuery.Where('StockQuantity > 0 AND Status = :active', [Ord(psActive)]);
  end;
  
  // Search text
  if AFilter.SearchText <> '' then
  begin
    Query.Where('(Name LIKE :search OR Sku LIKE :search OR Description LIKE :search)', 
      ['%' + AFilter.SearchText + '%']);
    CountQuery.Where('(Name LIKE :search OR Sku LIKE :search OR Description LIKE :search)', 
      ['%' + AFilter.SearchText + '%']);
  end;
  
  // Get total count
  Result.TotalCount := CountQuery.Count;
  Result.PageCount := (Result.TotalCount + AFilter.PageSize - 1) div AFilter.PageSize;
  
  // Sorting
  if AFilter.SortDesc then
    Query.OrderByDesc(AFilter.SortBy)
  else
    Query.OrderBy(AFilter.SortBy);
  
  // Pagination
  Query.Skip((AFilter.Page - 1) * AFilter.PageSize);
  Query.Take(AFilter.PageSize);
  
  Result.Products := Query.ToList;
end;

function TProductService.GetFeatured(ALimit: Integer): TObjectList<TProduct>;
begin
  Result := FContext.Query<TProduct>
    .Where('IsFeatured = 1 AND Status = :status', [Ord(psActive)])
    .OrderByDesc('CreatedAt')
    .Take(ALimit)
    .ToList;
end;

function TProductService.GetByCategory(ACategoryId: Integer): TObjectList<TProduct>;
begin
  Result := FContext.Query<TProduct>
    .Where('CategoryId = :catId AND Status = :status', [ACategoryId, Ord(psActive)])
    .OrderBy('Name')
    .ToList;
end;

function TProductService.GetRelated(AProductId: Integer; ALimit: Integer): TObjectList<TProduct>;
var
  Product: TProduct;
begin
  Product := GetById(AProductId);
  if Assigned(Product) then
  begin
    Result := FContext.Query<TProduct>
      .Where('CategoryId = :catId AND Id <> :id AND Status = :status', 
        [Product.CategoryId, AProductId, Ord(psActive)])
      .Take(ALimit)
      .ToList;
    Product.Free;
  end
  else
    Result := TObjectList<TProduct>.Create;
end;

procedure TProductService.Add(AProduct: TProduct);
begin
  AProduct.CreatedAt := Now;
  AProduct.UpdatedAt := Now;
  FContext.Insert(AProduct);
end;

procedure TProductService.Update(AProduct: TProduct);
begin
  AProduct.UpdatedAt := Now;
  FContext.Update(AProduct);
end;

procedure TProductService.Delete(AId: Integer);
var
  Product: TProduct;
begin
  Product := GetById(AId);
  if Assigned(Product) then
  begin
    Product.Status := psDiscontinued;
    FContext.Update(Product);
    Product.Free;
  end;
end;

procedure TProductService.UpdateStock(AProductId: Integer; AQuantity: Integer);
var
  Product: TProduct;
begin
  Product := GetById(AProductId);
  if Assigned(Product) then
  begin
    Product.StockQuantity := AQuantity;
    if AQuantity <= 0 then
      Product.Status := psOutOfStock
    else if Product.Status = psOutOfStock then
      Product.Status := psActive;
    FContext.Update(Product);
    Product.Free;
  end;
end;

procedure TProductService.DeductStock(AProductId: Integer; AQuantity: Integer);
var
  Product: TProduct;
begin
  Product := GetById(AProductId);
  if Assigned(Product) then
  begin
    Product.StockQuantity := Product.StockQuantity - AQuantity;
    if Product.StockQuantity <= 0 then
    begin
      Product.StockQuantity := 0;
      Product.Status := psOutOfStock;
    end;
    FContext.Update(Product);
    Product.Free;
  end;
end;

function TProductService.CheckStock(AProductId: Integer; AQuantity: Integer): Boolean;
var
  Product: TProduct;
begin
  Result := False;
  Product := GetById(AProductId);
  if Assigned(Product) then
  begin
    Result := Product.StockQuantity >= AQuantity;
    Product.Free;
  end;
end;

{ TCategoryService }

constructor TCategoryService.Create(AContext: TDbContext);
begin
  FContext := AContext;
end;

function TCategoryService.GetAll: TObjectList<TCategory>;
begin
  Result := FContext.Query<TCategory>
    .Where('IsActive = 1')
    .OrderBy('SortOrder, Name')
    .ToList;
end;

function TCategoryService.GetById(AId: Integer): TCategory;
begin
  Result := FContext.Find<TCategory>(AId);
end;

function TCategoryService.GetChildren(AParentId: Integer): TObjectList<TCategory>;
begin
  Result := FContext.Query<TCategory>
    .Where('ParentId = :parentId AND IsActive = 1', [AParentId])
    .OrderBy('SortOrder, Name')
    .ToList;
end;

function TCategoryService.GetRootCategories: TObjectList<TCategory>;
begin
  Result := FContext.Query<TCategory>
    .Where('(ParentId IS NULL OR ParentId = 0) AND IsActive = 1')
    .OrderBy('SortOrder, Name')
    .ToList;
end;

function TCategoryService.GetBreadcrumb(ACategoryId: Integer): TArray<TCategory>;
var
  List: TList<TCategory>;
  Cat: TCategory;
begin
  List := TList<TCategory>.Create;
  try
    Cat := GetById(ACategoryId);
    while Assigned(Cat) do
    begin
      List.Insert(0, Cat);
      if Cat.ParentId > 0 then
        Cat := GetById(Cat.ParentId)
      else
        Cat := nil;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TCategoryService.Add(ACategory: TCategory);
begin
  FContext.Insert(ACategory);
end;

procedure TCategoryService.Update(ACategory: TCategory);
begin
  FContext.Update(ACategory);
end;

procedure TCategoryService.Delete(AId: Integer);
var
  Category: TCategory;
begin
  Category := GetById(AId);
  if Assigned(Category) then
  begin
    Category.IsActive := False;
    FContext.Update(Category);
    Category.Free;
  end;
end;

{ TCartService }

constructor TCartService.Create(AContext: TDbContext; AProductService: TProductService);
begin
  FContext := AContext;
  FProductService := AProductService;
end;

function TCartService.GetCart(ACustomerId: Integer): TObjectList<TCartItem>;
begin
  Result := FContext.Query<TCartItem>
    .Where('CustomerId = :custId', [ACustomerId])
    .ToList;
end;

function TCartService.GetCartWithProducts(ACustomerId: Integer): TArray<TCartItemEx>;
var
  Items: TObjectList<TCartItem>;
  I: Integer;
begin
  Items := GetCart(ACustomerId);
  try
    SetLength(Result, Items.Count);
    for I := 0 to Items.Count - 1 do
    begin
      Result[I].Item := Items[I];
      Result[I].Product := FProductService.GetById(Items[I].ProductId);
    end;
  finally
    Items.Free;
  end;
end;

function TCartService.GetCartTotal(ACustomerId: Integer): Currency;
var
  CartItems: TArray<TCartItemEx>;
  Item: TCartItemEx;
begin
  Result := 0;
  CartItems := GetCartWithProducts(ACustomerId);
  for Item in CartItems do
  begin
    Result := Result + Item.LineTotal;
    if Assigned(Item.Product) then
      Item.Product.Free;
  end;
end;

function TCartService.GetCartItemCount(ACustomerId: Integer): Integer;
begin
  Result := FContext.Query<TCartItem>
    .Where('CustomerId = :custId', [ACustomerId])
    .Count;
end;

procedure TCartService.AddToCart(ACustomerId, AProductId: Integer; AQuantity: Integer);
var
  Existing: TCartItem;
  NewItem: TCartItem;
begin
  Existing := FContext.Query<TCartItem>
    .Where('CustomerId = :custId AND ProductId = :prodId', [ACustomerId, AProductId])
    .FirstOrDefault;
    
  if Assigned(Existing) then
  begin
    Existing.Quantity := Existing.Quantity + AQuantity;
    FContext.Update(Existing);
    Existing.Free;
  end
  else
  begin
    NewItem := TCartItem.Create;
    NewItem.CustomerId := ACustomerId;
    NewItem.ProductId := AProductId;
    NewItem.Quantity := AQuantity;
    NewItem.AddedAt := Now;
    FContext.Insert(NewItem);
    NewItem.Free;
  end;
end;

procedure TCartService.UpdateQuantity(ACustomerId, AProductId: Integer; AQuantity: Integer);
var
  Item: TCartItem;
begin
  Item := FContext.Query<TCartItem>
    .Where('CustomerId = :custId AND ProductId = :prodId', [ACustomerId, AProductId])
    .FirstOrDefault;
    
  if Assigned(Item) then
  begin
    if AQuantity <= 0 then
      FContext.Delete(Item)
    else
    begin
      Item.Quantity := AQuantity;
      FContext.Update(Item);
    end;
    Item.Free;
  end;
end;

procedure TCartService.RemoveFromCart(ACustomerId, AProductId: Integer);
begin
  FContext.ExecuteSQL(
    'DELETE FROM CartItems WHERE CustomerId = :custId AND ProductId = :prodId',
    [ACustomerId, AProductId]);
end;

procedure TCartService.ClearCart(ACustomerId: Integer);
begin
  FContext.ExecuteSQL('DELETE FROM CartItems WHERE CustomerId = :custId', [ACustomerId]);
end;

function TCartService.ValidateCart(ACustomerId: Integer; out AErrors: TArray<string>): Boolean;
var
  CartItems: TArray<TCartItemEx>;
  Item: TCartItemEx;
  ErrorList: TList<string>;
begin
  ErrorList := TList<string>.Create;
  try
    CartItems := GetCartWithProducts(ACustomerId);
    
    for Item in CartItems do
    begin
      if not Assigned(Item.Product) then
        ErrorList.Add(Format('Product ID %d no longer exists', [Item.Item.ProductId]))
      else if not Item.Product.IsInStock then
        ErrorList.Add(Format('%s is out of stock', [Item.Product.Name]))
      else if Item.Product.StockQuantity < Item.Item.Quantity then
        ErrorList.Add(Format('%s: only %d available (requested %d)', 
          [Item.Product.Name, Item.Product.StockQuantity, Item.Item.Quantity]));
          
      if Assigned(Item.Product) then
        Item.Product.Free;
    end;
    
    AErrors := ErrorList.ToArray;
    Result := ErrorList.Count = 0;
  finally
    ErrorList.Free;
  end;
end;

{ TOrderService }

constructor TOrderService.Create(AContext: TDbContext; AProductService: TProductService;
  ACartService: TCartService);
begin
  FContext := AContext;
  FProductService := AProductService;
  FCartService := ACartService;
end;

function TOrderService.GenerateOrderNumber: string;
begin
  Result := 'ORD-' + FormatDateTime('YYYYMMDD', Now) + '-' + 
            IntToStr(Random(9000) + 1000);
end;

function TOrderService.GetById(AId: Integer): TOrder;
begin
  Result := FContext.Find<TOrder>(AId);
end;

function TOrderService.GetByOrderNumber(const AOrderNumber: string): TOrder;
begin
  Result := FContext.Query<TOrder>
    .Where('OrderNumber = :orderNum', [AOrderNumber])
    .FirstOrDefault;
end;

function TOrderService.GetByCustomer(ACustomerId: Integer): TObjectList<TOrder>;
begin
  Result := FContext.Query<TOrder>
    .Where('CustomerId = :custId', [ACustomerId])
    .OrderByDesc('CreatedAt')
    .ToList;
end;

function TOrderService.GetOrderItems(AOrderId: Integer): TObjectList<TOrderItem>;
begin
  Result := FContext.Query<TOrderItem>
    .Where('OrderId = :orderId', [AOrderId])
    .ToList;
end;

function TOrderService.GetRecentOrders(ALimit: Integer): TObjectList<TOrder>;
begin
  Result := FContext.Query<TOrder>
    .OrderByDesc('CreatedAt')
    .Take(ALimit)
    .ToList;
end;

procedure TOrderService.CreateOrderItems(AOrderId, ACustomerId: Integer);
var
  CartItems: TArray<TCartItemEx>;
  Item: TCartItemEx;
  OrderItem: TOrderItem;
begin
  CartItems := FCartService.GetCartWithProducts(ACustomerId);
  
  for Item in CartItems do
  begin
    if Assigned(Item.Product) then
    begin
      OrderItem := TOrderItem.Create;
      OrderItem.OrderId := AOrderId;
      OrderItem.ProductId := Item.Product.Id;
      OrderItem.ProductName := Item.Product.Name;
      OrderItem.ProductSku := Item.Product.Sku;
      OrderItem.UnitPrice := Item.Product.Price;
      OrderItem.Quantity := Item.Item.Quantity;
      OrderItem.Discount := 0;
      OrderItem.TotalPrice := Item.Product.Price * Item.Item.Quantity;
      FContext.Insert(OrderItem);
      OrderItem.Free;
      
      FProductService.DeductStock(Item.Product.Id, Item.Item.Quantity);
      Item.Product.Free;
    end;
  end;
end;

function TOrderService.CreateOrder(ACustomerId, AShippingAddressId: Integer;
  APaymentMethod: TPaymentMethod; const ANotes: string): TOrder;
var
  Errors: TArray<string>;
begin
  if not FCartService.ValidateCart(ACustomerId, Errors) then
    raise EInvalidOperationException.Create('Cart validation failed: ' + string.Join('; ', Errors));
  
  Result := TOrder.Create;
  Result.OrderNumber := GenerateOrderNumber;
  Result.CustomerId := ACustomerId;
  Result.ShippingAddressId := AShippingAddressId;
  Result.Status := osCreated;
  Result.Subtotal := CalculateSubtotal(ACustomerId);
  Result.ShippingCost := CalculateShipping(ACustomerId, AShippingAddressId);
  Result.TaxAmount := CalculateTax(Result.Subtotal);
  Result.DiscountAmount := 0;
  Result.TotalAmount := Result.Subtotal + Result.ShippingCost + Result.TaxAmount - Result.DiscountAmount;
  Result.PaymentMethod := APaymentMethod;
  Result.Notes := ANotes;
  Result.CreatedAt := Now;
  
  FContext.Insert(Result);
  CreateOrderItems(Result.Id, ACustomerId);
  FCartService.ClearCart(ACustomerId);
end;

procedure TOrderService.UpdateStatus(AOrderId: Integer; AStatus: TOrderStatus);
var
  Order: TOrder;
begin
  Order := GetById(AOrderId);
  if Assigned(Order) then
  begin
    Order.Status := AStatus;
    FContext.Update(Order);
    Order.Free;
  end;
end;

procedure TOrderService.MarkAsPaid(AOrderId: Integer; const APaymentRef: string);
var
  Order: TOrder;
begin
  Order := GetById(AOrderId);
  if Assigned(Order) then
  begin
    Order.Status := osPaid;
    Order.PaymentRef := APaymentRef;
    Order.PaidAt := Now;
    FContext.Update(Order);
    Order.Free;
  end;
end;

procedure TOrderService.MarkAsShipped(AOrderId: Integer; const ATrackingNumber: string);
var
  Order: TOrder;
begin
  Order := GetById(AOrderId);
  if Assigned(Order) then
  begin
    Order.Status := osShipped;
    Order.ShippedAt := Now;
    FContext.Update(Order);
    Order.Free;
  end;
end;

procedure TOrderService.CancelOrder(AOrderId: Integer; const AReason: string);
var
  Order: TOrder;
  Items: TObjectList<TOrderItem>;
  Item: TOrderItem;
begin
  Order := GetById(AOrderId);
  if Assigned(Order) and Order.CanCancel then
  begin
    Items := GetOrderItems(AOrderId);
    try
      for Item in Items do
        FProductService.UpdateStock(Item.ProductId, 
          FProductService.GetById(Item.ProductId).StockQuantity + Item.Quantity);
    finally
      Items.Free;
    end;
    
    Order.Status := osCancelled;
    Order.Notes := Order.Notes + sLineBreak + 'Cancelled: ' + AReason;
    FContext.Update(Order);
    Order.Free;
  end;
end;

procedure TOrderService.RefundOrder(AOrderId: Integer; const AReason: string);
var
  Order: TOrder;
begin
  Order := GetById(AOrderId);
  if Assigned(Order) and Order.CanRefund then
  begin
    Order.Status := osRefunded;
    Order.Notes := Order.Notes + sLineBreak + 'Refunded: ' + AReason;
    FContext.Update(Order);
    Order.Free;
  end;
end;

function TOrderService.CalculateSubtotal(ACustomerId: Integer): Currency;
begin
  Result := FCartService.GetCartTotal(ACustomerId);
end;

function TOrderService.CalculateShipping(ACustomerId: Integer; AAddressId: Integer): Currency;
begin
  Result := 9.99; // Flat rate shipping
end;

function TOrderService.CalculateTax(ASubtotal: Currency): Currency;
begin
  Result := ASubtotal * 0.1; // 10% tax
end;

{ TCustomerService }

constructor TCustomerService.Create(AContext: TDbContext);
begin
  FContext := AContext;
end;

function TCustomerService.HashPassword(const APassword: string): string;
begin
  Result := THashSHA2.GetHashString(APassword, THashSHA2.TSHA2Version.SHA256);
end;

function TCustomerService.VerifyPassword(const APassword, AHash: string): Boolean;
begin
  Result := HashPassword(APassword) = AHash;
end;

function TCustomerService.GetById(AId: Integer): TCustomer;
begin
  Result := FContext.Find<TCustomer>(AId);
end;

function TCustomerService.GetByEmail(const AEmail: string): TCustomer;
begin
  Result := FContext.Query<TCustomer>
    .Where('Email = :email', [LowerCase(AEmail)])
    .FirstOrDefault;
end;

function TCustomerService.Authenticate(const AEmail, APassword: string): TCustomer;
begin
  Result := GetByEmail(AEmail);
  if Assigned(Result) then
  begin
    if not VerifyPassword(APassword, Result.PasswordHash) then
      FreeAndNil(Result)
    else if not Result.IsActive then
      FreeAndNil(Result)
    else
    begin
      Result.LastLoginAt := Now;
      FContext.Update(Result);
    end;
  end;
end;

function TCustomerService.Register(const AEmail, APassword, AFirstName, ALastName: string): TCustomer;
begin
  if Assigned(GetByEmail(AEmail)) then
    raise EInvalidOperationException.Create('Email already registered');
    
  Result := TCustomer.Create;
  Result.Email := LowerCase(AEmail);
  Result.PasswordHash := HashPassword(APassword);
  Result.FirstName := AFirstName;
  Result.LastName := ALastName;
  Result.IsActive := True;
  Result.IsVerified := False;
  Result.CreatedAt := Now;
  FContext.Insert(Result);
end;

procedure TCustomerService.Update(ACustomer: TCustomer);
begin
  FContext.Update(ACustomer);
end;

procedure TCustomerService.ChangePassword(ACustomerId: Integer; 
  const AOldPassword, ANewPassword: string);
var
  Customer: TCustomer;
begin
  Customer := GetById(ACustomerId);
  if Assigned(Customer) then
  begin
    if not VerifyPassword(AOldPassword, Customer.PasswordHash) then
      raise EInvalidOperationException.Create('Invalid current password');
    Customer.PasswordHash := HashPassword(ANewPassword);
    FContext.Update(Customer);
    Customer.Free;
  end;
end;

procedure TCustomerService.ResetPassword(const AEmail: string);
begin
  // Implementation would send reset email
end;

function TCustomerService.GetAddresses(ACustomerId: Integer): TObjectList<TShippingAddress>;
begin
  Result := FContext.Query<TShippingAddress>
    .Where('CustomerId = :custId', [ACustomerId])
    .ToList;
end;

function TCustomerService.GetDefaultAddress(ACustomerId: Integer): TShippingAddress;
begin
  Result := FContext.Query<TShippingAddress>
    .Where('CustomerId = :custId AND IsDefault = 1', [ACustomerId])
    .FirstOrDefault;
end;

procedure TCustomerService.AddAddress(AAddress: TShippingAddress);
begin
  FContext.Insert(AAddress);
end;

procedure TCustomerService.UpdateAddress(AAddress: TShippingAddress);
begin
  FContext.Update(AAddress);
end;

procedure TCustomerService.DeleteAddress(AAddressId: Integer);
var
  Addr: TShippingAddress;
begin
  Addr := FContext.Find<TShippingAddress>(AAddressId);
  if Assigned(Addr) then
  begin
    FContext.Delete(Addr);
    Addr.Free;
  end;
end;

procedure TCustomerService.SetDefaultAddress(ACustomerId, AAddressId: Integer);
begin
  FContext.ExecuteSQL(
    'UPDATE ShippingAddresses SET IsDefault = 0 WHERE CustomerId = :custId',
    [ACustomerId]);
  FContext.ExecuteSQL(
    'UPDATE ShippingAddresses SET IsDefault = 1 WHERE Id = :addrId',
    [AAddressId]);
end;

{ TInventoryService }

constructor TInventoryService.Create(AContext: TDbContext);
begin
  FContext := AContext;
end;

function TInventoryService.GetLowStockProducts: TObjectList<TProduct>;
begin
  Result := FContext.Query<TProduct>
    .Where('StockQuantity > 0 AND StockQuantity <= LowStockThreshold AND Status = :status',
      [Ord(psActive)])
    .ToList;
end;

function TInventoryService.GetOutOfStockProducts: TObjectList<TProduct>;
begin
  Result := FContext.Query<TProduct>
    .Where('StockQuantity <= 0 OR Status = :status', [Ord(psOutOfStock)])
    .ToList;
end;

procedure TInventoryService.AdjustStock(AProductId: Integer; AQuantityChange: Integer;
  const AReason: string);
var
  Product: TProduct;
begin
  Product := FContext.Find<TProduct>(AProductId);
  if Assigned(Product) then
  begin
    Product.StockQuantity := Product.StockQuantity + AQuantityChange;
    if Product.StockQuantity < 0 then
      Product.StockQuantity := 0;
    FContext.Update(Product);
    Product.Free;
  end;
end;

procedure TInventoryService.SetStock(AProductId: Integer; AQuantity: Integer;
  const AReason: string);
var
  Product: TProduct;
begin
  Product := FContext.Find<TProduct>(AProductId);
  if Assigned(Product) then
  begin
    Product.StockQuantity := AQuantity;
    if AQuantity <= 0 then
      Product.Status := psOutOfStock
    else if Product.Status = psOutOfStock then
      Product.Status := psActive;
    FContext.Update(Product);
    Product.Free;
  end;
end;

function TInventoryService.GetStockValue: Currency;
begin
  Result := 0;
  // SELECT SUM(StockQuantity * CostPrice) FROM Products WHERE Status <> discontinued
end;

function TInventoryService.GetStockCount: Integer;
begin
  Result := FContext.Query<TProduct>
    .Where('Status <> :status', [Ord(psDiscontinued)])
    .Count;
end;

end.
