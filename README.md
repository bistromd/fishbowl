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

## Pick and Ship Orders (two-step ImportRq flow)

Step 1 picks inventory to shipping lanes (`ImportPickingData`). Step 2 ships the picked order (`ImportShippingData`).

```ruby
# Both steps in sequence (recommended):
Fishbowl::Models::Shipping.pick_and_ship(
  Fishbowl::Models::Shipping.new('251007141640253184565', 'H - FedEx Home Delivery', '1234432556')
)
# Step 1 pick:  "251007141640253184565","Commit"
# Step 2 ship:  "S251007141640253184565","H - FedEx Home Delivery","1234432556","Shipped"

# Or run each step manually:
Fishbowl::Models::Picking.import('251007141640253184565')
Fishbowl::Models::Shipping.ship(
  Fishbowl::Models::Shipping.new('251007141640253184565', 'H - FedEx Home Delivery', '1234432556')
)

# Bulk:
Fishbowl::Models::Shipping.pick_and_ship([
  { order_number: '251007141640253184565', carrier: 'H - FedEx Home Delivery', tracking_number: '1234432556' },
  { order_number: '251013151111589397339', carrier: 'UPS Ground', tracking_number: '1Z999AA10123456785' }
])
```

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

## All Inventory
```ruby
Fishbowl::Models::Inventory.all
```

## Run Custom MySQL Query
```ruby
Fishbowl::Models::Base.send_query_request('SELECT * FROM CUSTOMER LIMIT 2')
```

# Not intended as its own gem. Feel free to fork or clone or copy code.
