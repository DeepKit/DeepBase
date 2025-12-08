# E-Commerce Application Template

完整的电商应用模板，展示 UniBase ORM 和服务层架构。

## 功能特性

- **商品管理**: 分类、搜索、筛选、库存
- **购物车**: 添加、修改、验证、结算
- **订单处理**: 创建、支付、发货、取消、退款
- **客户管理**: 注册、登录、地址簿
- **库存管理**: 库存预警、调整、统计

## 文件结构

```
ECommerceApp/
├── ECommerce.Entities.pas    # 实体定义 (ORM 映射)
├── ECommerce.Services.pas    # 业务服务层
└── README.md
```

## 实体模型

| 实体 | 说明 |
|------|------|
| `TProduct` | 商品 (SKU/价格/库存/状态) |
| `TCategory` | 分类 (支持多级) |
| `TCustomer` | 客户 (登录/验证) |
| `TShippingAddress` | 收货地址 |
| `TOrder` | 订单头 (状态/金额/支付) |
| `TOrderItem` | 订单明细 |
| `TCartItem` | 购物车项 |

## 服务层

| 服务 | 功能 |
|------|------|
| `TProductService` | 商品 CRUD、搜索、库存 |
| `TCategoryService` | 分类树、面包屑 |
| `TCartService` | 购物车操作、验证 |
| `TOrderService` | 订单全流程 |
| `TCustomerService` | 客户注册登录 |
| `TInventoryService` | 库存管理 |

## 使用示例

### 商品搜索

```pascal
var
  Filter: TProductFilter;
  Result: TProductSearchResult;
begin
  Filter := TProductFilter.Default;
  Filter.CategoryId := 5;
  Filter.MinPrice := 100;
  Filter.MaxPrice := 500;
  Filter.InStockOnly := True;
  Filter.SearchText := 'laptop';
  Filter.Page := 1;
  
  Result := ProductService.Search(Filter);
  // Result.Products, Result.TotalCount, Result.PageCount
end;
```

### 购物车操作

```pascal
// 添加商品到购物车
CartService.AddToCart(CustomerId, ProductId, 2);

// 获取购物车总额
var Total := CartService.GetCartTotal(CustomerId);

// 验证购物车
var Errors: TArray<string>;
if not CartService.ValidateCart(CustomerId, Errors) then
  ShowMessage(string.Join(#13, Errors));
```

### 创建订单

```pascal
var
  Order: TOrder;
begin
  Order := OrderService.CreateOrder(
    CustomerId,
    ShippingAddressId,
    pmCreditCard,
    '请尽快发货'
  );
  
  // 支付成功后
  OrderService.MarkAsPaid(Order.Id, 'PAY-123456');
  
  // 发货
  OrderService.MarkAsShipped(Order.Id, 'SF1234567890');
end;
```

### 客户注册

```pascal
var Customer := CustomerService.Register(
  'user@example.com',
  'password123',
  '张',
  '三'
);
```

## 订单状态流转

```
Created -> Pending -> Paid -> Processing -> Shipped -> Delivered
                  \-> Cancelled
                           \-> Refunded
```

## 数据库表

模板使用以下表（需提前创建）:

- Categories
- Products
- Customers
- ShippingAddresses
- Orders
- OrderItems
- CartItems

## 扩展建议

1. **优惠券系统**: 添加 Coupons 表和折扣计算
2. **评价系统**: 添加 Reviews 表
3. **推荐引擎**: 基于购买历史推荐
4. **多仓库**: 添加 Warehouses 和库存分配
5. **支付网关**: 集成支付宝/微信支付
