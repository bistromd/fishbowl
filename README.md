# Get started
This project has taken lots of ideas from the original gem: https://github.com/zion/fishbowl

To use:
```ruby
gem 'fishbowl', github: 'bistromd/fishbowl', branch: 'main'
```

# To configure:
```ruby
Fishbowl.configure do |config|
  config.username = 'admin'
  config.password = 'password'
  config.host = 'fishbowl.host'
  config.app_id = '12345678'
  config.app_name = 'Fishbowl Ruby Gem'
  config.app_description = 'Fishbowl Ruby Gem'
  config.encode_password = true
  config.debug = true
  config.mysql_url = 'mysql://root:password@fishbowldb.host:3306/db?charset=utf8mb4'
end
```

-------

# To Connect and Login
```ruby
Fishbowl::Connection.connect
```
--------

# Make Requests
## Find Sales Order
```ruby
Fishbowl::Models::SalesOrder.find(1_145_064, 'json')
```

## Find Customer
```ruby
Fishbowl::Models::Customer.find(139015)
Fishbowl::Models::Customer.find_name('John Doe')
```

## Create Customer
```ruby
customer = Fishbowl::Models::Customer.new('TEST-1234', 'Test User', 'test@testing1234.com')
customer.add_address('22 Sample testing street ', 'Naples', 'FL', 34109)
customer.add_custom_fields(2, false, 'Custom Data', 'Created For Testing')
response = customer.save
```

## Import Requests
```ruby
Fishbowl::Models::ImportRequest.all('json')
Fishbowl::Models::ImportRequest.headers('ImportCustomers')
```

## Pick, Pack, Track, and Ship Orders

Four-step flow using column names from **your** Fishbowl server. Run this first to verify headers for your version:

```ruby
ruby script/ship_diagnostic.rb headers
```

```ruby
Fishbowl::Models::Shipping.pick_and_ship(
  Fishbowl::Models::Shipping.new('260706030519667150579', 'H - FedEx Home Delivery', '1234432556')
)

# Step 1 — ImportPickingData:  OrderNumber,Action / "ORDER","Finish"
# Step 2 — ImportPackingData:   SONum / "260706030519667150579"
# Step 3 — ImportShipCartonTracking: Ship Number,Carton Number,Tracking Number
# Step 4 — ImportShippingData:  ShipNum,Date,Carrier,Carrier Service
```

Local diagnostic script (uses `.env`):

```bash
ruby script/ship_diagnostic.rb inspect 260706030519667150579
ruby script/ship_diagnostic.rb flow 260706030519667150579 "H - FedEx Home Delivery" 1234432556
```

### Scripts

#### `script/ship_diagnostic.rb`

Primary CLI for the pick/pack/track/ship flow and debugging.

```bash
# Inspect SO + shipment state via ExecuteQuery + LoadSORq
ruby script/ship_diagnostic.rb inspect 260706030519667150579

# Show server-specific import headers
ruby script/ship_diagnostic.rb headers

# Run the full pick → pack → track → ship flow
ruby script/ship_diagnostic.rb flow 260706030519667150579 "H - FedEx Home Delivery" 1234432556

# If the order was manually picked in the Fishbowl UI, skip pick and just pack/track/ship
ruby script/ship_diagnostic.rb finish 260706030519667150579 "H - FedEx Home Delivery" 1234432556
```

#### `script/add_inventory_to_order_items.rb`

Adds on-hand inventory for every **inventory-type** line item on a sales order using `ImportAddInventory`.

- Automatically **skips non-inventory parts** (packaging, etc.)
- For **tracked parts**, automatically supplies a lot number and expiration date (required by this Fishbowl server)

```bash
# Preview what will be imported (no changes)
ruby script/add_inventory_to_order_items.rb 260706030039773411663 --dry-run

# Import inventory adjustments for the order's items
ruby script/add_inventory_to_order_items.rb 260706030039773411663

# Override location if needed
ruby script/add_inventory_to_order_items.rb 260706030039773411663 --location Stock
```

#### Fulfill in one command: add inventory + ship

If pick returns success but **no shipment is created**, it's usually an inventory/allocation issue. This command adds inventory first, then runs the ship flow:

```bash
ruby script/ship_diagnostic.rb fulfill 260706030039773411663 "H - FedEx Home Delivery" 1234432556
```

### `.env` variables used by scripts

See `.env.example` for the full list. Common ones:

- `FISHBOWL_HOST`, `FISHBOWL_PORT`, `FISHBOWL_USERNAME`, `FISHBOWL_PASSWORD`
- `FISHBOWL_APP_ID`, `FISHBOWL_APP_NAME`, `FISHBOWL_APP_DESCRIPTION`
- `FISHBOWL_ENCODE_PASSWORD` (`true` recommended)
- `FISHBOWL_MYSQL_URL` (optional; enables MySQL helpers)
- `FISHBOWL_ORDER_NUMBER`, `FISHBOWL_CARRIER`, `FISHBOWL_TRACKING_NUMBER` (script defaults)
- `FISHBOWL_INVENTORY_LOCATION` (defaults to `Stock` in the order’s location group)
- `FISHBOWL_INVENTORY_DEFAULT_COST` (default unit cost when SO line has no price)
- `FISHBOWL_INVENTORY_LOT_PREFIX`, `FISHBOWL_INVENTORY_EXPIRATION_DAYS`

## Create Sales order with sales order line items
```ruby
items = Fishbowl::Models::SalesOrderItem.items({'70-61-06' => 1, '70-53-05' => 1})
sales_order = Fishbowl::Models::SalesOrder.new('TEST-ORDER-12345b', 'John Doe', 'WA', "******* SAMPLE NOTES *******")
sales_order.add_address('22 Sample testing street ', 'Naples', 'FL', 34109)
sales_order.add_items(items)
```

## Update/Create Sales order detail
```ruby
sales_order_details = Fishbowl::Models::SalesOrderDetail.new('TEST-ORDER-12345a')
sales_order_details.add_line_item('sku', 'Smoked chips', 1)
sales_order_details.save
```

## Void Sales Order
```ruby
Fishbowl::Models::SalesOrder.void('TEST-ORDER-12345b')
```

## Issue Sales Order
```ruby
Fishbowl::Models::SalesOrder.issue('TEST-ORDER-12345b')
```

## All Inventory
```ruby
Fishbowl::Models::Inventory.all
```

## Run Custom MySQL Query
```ruby
Fishbowl::Models::Base.send_query_request('SELECT * FROM CUSTOMER LIMIT 2')
```

# Not intended as its own gem. Feel free to fork or clone or copy code.
