#!/usr/bin/env ruby
# frozen_string_literal: true

# Add on-hand inventory for every line item on a sales order (ImportAddInventory).
#
# Setup:
#   cp .env.example .env
#   bundle install
#
# Usage:
#   ruby script/add_inventory_to_order_items.rb ORDER_NUMBER
#   ruby script/add_inventory_to_order_items.rb ORDER_NUMBER --location "CTIN-Stock"
#   ruby script/add_inventory_to_order_items.rb ORDER_NUMBER --dry-run
#   ruby script/add_inventory_to_order_items.rb ORDER_NUMBER --ship
#
# Env vars (see .env.example):
#   FISHBOWL_INVENTORY_LOCATION — default location when --location is omitted
#   FISHBOWL_INVENTORY_DEFAULT_COST — unit cost when the SO line has no price

require 'optparse'
require_relative 'ship_diagnostic'

module AddInventoryToOrderItems
  module_function

  def print_plan(adjustments, location)
    puts "\nLocation: #{location}"
    puts format('%-20s %8s %6s %10s  %s', 'Part', 'Qty', 'UOM', 'Cost', 'Lot')
    puts '-' * 70
    adjustments.each do |row|
      lot = row.lot_number.to_s.empty? ? '-' : row.lot_number
      exp = row.expiration_date.to_s.empty? ? '' : " exp=#{row.expiration_date}"
      puts format('%-20s %8s %6s %10s  %s%s', row.part_number, row.quantity, row.uom, row.cost, lot, exp)
    end
    puts "\nCSV payload:"
    puts Fishbowl::Models::InventoryAdjustment.header_row
    adjustments.each { |row| puts row.to_csv }
  end
end

if __FILE__ == $PROGRAM_NAME
  options = { dry_run: false, ship: false }

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: ruby script/add_inventory_to_order_items.rb ORDER_NUMBER [options]'
    opts.on('--location LOCATION', 'Fishbowl location (overrides FISHBOWL_INVENTORY_LOCATION)') do |value|
      options[:location] = value
    end
    opts.on('--cost COST', 'Default unit cost when the line item has no price') do |value|
      options[:cost] = value
    end
    opts.on('--note NOTE', 'Note on each inventory adjustment') do |value|
      options[:note] = value
    end
    opts.on('--date DATE', 'Adjustment date (YYYY-MM-DD)') do |value|
      options[:date] = value
    end
    opts.on('--dry-run', 'Show line items and CSV without importing') do
      options[:dry_run] = true
    end
    opts.on('--ship', 'After import, run pick_and_ship using FISHBOWL_CARRIER / FISHBOWL_TRACKING_NUMBER') do
      options[:ship] = true
    end
  end

  order_number = ARGV.shift
  if order_number.nil?
    puts parser
    exit 1
  end

  parser.parse!(ARGV)

  ShipDiagnostic.load_dotenv!
  ShipDiagnostic.configure_fishbowl!
  ShipDiagnostic.connect!

  puts "\n--- Order: #{order_number} ---"
  ShipDiagnostic.preflight(order_number)

  preview_opts = options.slice(:location, :cost, :note, :date)
  skipped = Fishbowl::Models::InventoryAdjustment.skipped_items_for_order(order_number)
  unless skipped.empty?
    puts "\nSkipping non-inventory line items:"
    skipped.each do |item|
      puts "  #{item[:part_number]} x#{item[:quantity]} (#{item[:reason]})"
    end
  end

  adjustments = Fishbowl::Models::InventoryAdjustment.preview_for_order(order_number, **preview_opts)
  location = adjustments.first&.location || options[:location] || ENV['FISHBOWL_INVENTORY_LOCATION']
  AddInventoryToOrderItems.print_plan(adjustments, location)

  if options[:dry_run]
    puts "\nDry run — no import sent."
    exit 0
  end

  print "\n==> ImportAddInventory (#{adjustments.length} items)... "
  response = Fishbowl::Models::InventoryAdjustment.add_for_order(order_number, **preview_opts)
  puts ShipDiagnostic.import_summary(response)
  ShipDiagnostic.dump_response('add_inventory', response)

  if options[:ship]
    shipment = ShipDiagnostic.shipment(order_number)
    puts "\nRunning pick_and_ship..."
    Fishbowl::Models::Shipping.pick_and_ship(shipment)
    puts "\nDone. Re-inspecting order..."
    ShipDiagnostic.inspect_order(order_number)
  else
    puts "\nInventory added. Next: ruby script/ship_diagnostic.rb flow #{order_number}"
  end
end
