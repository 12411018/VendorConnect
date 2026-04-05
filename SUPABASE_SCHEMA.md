iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii# VendorLink Supabase Database Schema

**Database**: vmjojqhtvhwuqopdqgpa (Supabase PostgreSQL)  
**Schema**: public  
**Last Updated**: April 3, 2026

---

## 📋 Table: `profiles`

**Purpose**: User profiles for all authenticated users (wholesalers and retailers)  
**Primary Key**: `id` (UUID)  
**Foreign Keys**: None  

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NOT NULL | | User ID (references Supabase auth.users.id) |
| `email` | Text | NULL | | User email address |
| `name` | Text | NULL | | User display name |
| `role` | Text | NULL | | User role ('wholesaler' or 'retailer') |
| `created_at` | Timestamp | NOT NULL | CURRENT_TIMESTAMP | Account creation timestamp |
| `updated_at` | Timestamp | NOT NULL | CURRENT_TIMESTAMP | Last update timestamp |

**RLS Policies**:
- Users can SELECT/UPDATE their own profile (WHERE auth.uid() = id)
- Wholesalers can SELECT retail profiles for order visibility

---

## 📋 Table: `products`

**Purpose**: Product catalog managed by wholesalers  
**Primary Key**: `id` (UUID)  
**Foreign Keys**: `vendor_id` → `profiles.id`  
**Indexes**: `idx_products_vendor_id`  

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NOT NULL | gen_random_uuid() | Product ID |
| `vendor_id` | UUID | NOT NULL | | FK to profiles.id (wholesaler who created product) |
| `name` | Text | NOT NULL | | Product name |
| `price` | Numeric | NOT NULL | | Unit price |
| `stock_qty` | Integer | NOT NULL | 0 | Available stock quantity |
| `sku` | Text | NULL | | Stock keeping unit (optional) |
| `description` | Text | NULL | | Product description |
| `category` | Text | NULL | | Product category |
| `type` | Text | NULL | | Product type/subcategory |
| `image_url` | Text | NULL | | URL to product image |
| `created_at` | Timestamp | NOT NULL | CURRENT_TIMESTAMP | Product creation timestamp |
| `updated_at` | Timestamp | NOT NULL | CURRENT_TIMESTAMP | Last update timestamp |

**RLS Policies**:
- Everyone can SELECT products (public browsing)
- Wholesalers can INSERT their own products (WHERE vendor_id = auth.uid())
- Wholesalers can UPDATE/DELETE their own products (WHERE vendor_id = auth.uid())

**Insert Columns Used**: `vendor_id`, `name`, `price`, `stock_qty`, `sku`, `category`, `type`, `description`, `image_url`

---

## 📋 Table: `orders`

**Purpose**: Customer orders grouped by vendor/wholesaler  
**Primary Key**: `id` (UUID)  
**Foreign Keys**: 
  - `vendor_id` → `profiles.id` (wholesaler)
  - `retailer_id` → `profiles.id` (retailer)  
**Indexes**: `idx_orders_vendor_id`, `idx_orders_retailer_id`, `orders_order_number_key` (unique)  
**Unique Constraints**: `order_number`  

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | UUID | NOT NULL | gen_random_uuid() | Order ID |
| `order_number` | Text | NOT NULL | | Unique order reference (ORD-{timestamp}) |
| `vendor_id` | UUID | NOT NULL | | FK to profiles.id (wholesaler) |
| `retailer_id` | UUID | NOT NULL | | FK to profiles.id (retailer placing order) |
| `order_items` | JSONB | NOT NULL | | Array of order items (see schema below) |
| `total_amount` | Numeric | NOT NULL | | Total order value |
| `quantity` | Integer | NOT NULL | | Total item count |
| `shipping_name` | Text | NULL | | Customer name for shipping |
| `shipping_address` | Text | NULL | | Shipping address |
| `status` | Text | NOT NULL | 'pending' | Order status: 'pending', 'accepted', 'rejected' |
| `created_at` | Timestamp | NOT NULL | CURRENT_TIMESTAMP | Order creation timestamp |
| `updated_at` | Timestamp | NOT NULL | CURRENT_TIMESTAMP | Last status update timestamp |

**RLS Policies**:
- Retailers can INSERT orders where `retailer_id = auth.uid()`
- Retailers can SELECT their own orders (WHERE `retailer_id = auth.uid()`)
- Wholesalers can SELECT orders where `vendor_id = auth.uid()`
- Wholesalers can UPDATE order status (WHERE `vendor_id = auth.uid()`)

**Insert Columns Used**: `order_number`, `vendor_id`, `retailer_id`, `shipping_name`, `shipping_address`, `order_items`, `total_amount`, `quantity`, `status`

### **Nested Schema: `order_items` (JSONB Array)**

Each item in `order_items` array has this structure:

```json
{
  "product_id": "uuid-string",
  "product_name": "Product Name",
  "sku": "SKU-123",
  "category": "Category Name",
  "type": "Product Type",
  "quantity": 5,
  "unit_price": 99.99,
  "total_price": 499.95
}
```

---

## 🔄 Data Flow

### **Order Placement Flow**:
1. Retailer browses products in dashboard (SELECT from products WHERE vendor_id = wholesaler)
2. Products added to cart with quantity
3. Cart items grouped by `vendor_id` (one vendor per order)
4. Order created in `orders` table with:
   - `order_items` populated with product details from cart
   - `status` set to 'pending'
   - `total_amount` calculated from order_items
5. Notification sent to wholesaler

### **Order Status Flow**:
1. Wholesaler sees order in their Orders tab (orders WHERE vendor_id = auth.uid())
2. Wholesaler clicks Accept or Reject
3. Order status updated: `UPDATE orders SET status = 'accepted'|'rejected' WHERE id = ?`
4. Retailer sees status update in their Orders tab (SELECT WHERE retailer_id = auth.uid())
5. Messages displayed:
   - `'accepted'` → "Order accepted. You will get it soon."
   - `'rejected'` → "Order canceled by wholesaler."
   - `'pending'` → "Waiting for wholesaler response."

---

## 📊 Fallback Insert Strategy

When inserting orders, the app tries multiple payload candidates (from most complete to minimal):

### **Candidate 1** (Full):
```dart
{
  'order_number', 'vendor_id', 'retailer_id', 'shipping_name', 
  'shipping_address', 'order_items', 'total_amount', 'quantity', 'status'
}
```

### **Candidate 2** (Without shipping):
```dart
{
  'order_number', 'vendor_id', 'retailer_id', 'order_items', 
  'total_amount', 'quantity', 'status'
}
```

### **Candidate 3** (Minimal Required):
```dart
{
  'vendor_id', 'retailer_id', 'order_items', 'status'
}
```

---

## ✅ Validation Checklist

- ✅ All tables have `id` (primarykey) and timestamps (`created_at`, `updated_at`)
- ✅ Foreign key constraints: `vendor_id` → profiles, `retailer_id` → profiles
- ✅ Unique constraint: `order_number` (prevents duplicate order references)
- ✅ Indexes on commonly filtered columns: `vendor_id`, `retailer_id`
- ✅ RLS policies enable multi-tenant separation (wholesalers can't see other wholesalers' data)
- ✅ JSONB `order_items` column stores product details (no flat product columns needed in orders table)

---

## 🛠️ How to Verify This Schema in Supabase

1. **Via SQL Editor**:
   ```sql
   -- View orders table structure
   SELECT column_name, data_type, is_nullable 
   FROM information_schema.columns 
   WHERE table_schema = 'public' AND table_name = 'orders' 
   ORDER BY ordinal_position;
   
   -- View products table structure
   SELECT column_name, data_type, is_nullable 
   FROM information_schema.columns 
   WHERE table_schema = 'public' AND table_name = 'products' 
   ORDER BY ordinal_position;
   ```

2. **Via Table Editor** (Dashboard):
   - Go to Database → Tables
   - Click on each table name to view structure
   - Check column names and types

3. **Via Flutter App** (Run schema fetch):
   ```bash
   node fetch-schema.js
   ```

---

## 📝 Notes

- **No `product_id` column in orders**: Product data is embedded in `order_items` JSON, not stored flatly
- **Timestamps**: All tables auto-maintain `created_at` and `updated_at` for audit trail
- **Orders are mono-vendor**: Each order belongs to exactly one wholesaler (enforced by app logic)
- **RLS is mandatory**: Enables secure multi-tenant data isolation without additional WHERE clauses

