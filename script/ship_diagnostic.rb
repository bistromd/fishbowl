#!/usr/bin/env ruby
# frozen_string_literal: true

# Local diagnostic runner for Fishbowl pick/pack/track/ship flow.
#
# Setup:
#   cp .env.example .env
#   # edit .env with your Fishbowl host, credentials, and test order number
#   bundle install
#
# Usage:
#   ruby script/ship_diagnostic.rb help
#   ruby script/ship_diagnostic.rb inspect 260706030519667150579
#   ruby script/ship_diagnostic.rb query "SELECT so.num, so.statusId FROM so WHERE so.num = '260706030519667150579'"
#   ruby script/ship_diagnostic.rb pick 260706030519667150579
#   ruby script/ship_diagnostic.rb pack 260706030519667150579
#   ruby script/ship_diagnostic.rb track 260706030519667150579 "H - FedEx Home Delivery" 1234432556
#   ruby script/ship_diagnostic.rb ship 260706030519667150579 "H - FedEx Home Delivery" 1234432556
#   ruby script/ship_diagnostic.rb flow 260706030519667150579 "H - FedEx Home Delivery" 1234432556
#
# Env vars (see .env.example): FISHBOWL_HOST, FISHBOWL_USERNAME, FISHBOWL_PASSWORD,
# FISHBOWL_APP_ID, FISHBOWL_APP_NAME, FISHBOWL_APP_DESCRIPTION, optional FISHBOWL_MYSQL_URL

require 'json'
require 'fileutils'
require 'optparse'

ROOT = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'lib'))
require 'fishbowl'

module ShipDiagnostic
  module_function

  def load_dotenv!(path = File.join(ROOT, '.env'))
    return unless File.exist?(path)

    File.readlines(path, chomp: true).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')

      key, value = line.split('=', 2)
      next if key.nil? || value.nil?

      ENV[key] ||= value.delete_prefix('"').delete_suffix('"')
    end
  end

  def configure_fishbowl!
    missing = %w[FISHBOWL_HOST FISHBOWL_USERNAME FISHBOWL_PASSWORD FISHBOWL_APP_ID].reject { |key| ENV[key]&.strip&.length&.positive? }
    unless missing.empty?
      abort "Missing required env vars: #{missing.join(', ')}\nCopy .env.example to .env and fill in credentials."
    end

    Fishbowl.configure do |config|
      config.host = ENV.fetch('FISHBOWL_HOST')
      config.port = (ENV['FISHBOWL_PORT'] || 28_192).to_i
      config.username = ENV.fetch('FISHBOWL_USERNAME')
      config.password = ENV.fetch('FISHBOWL_PASSWORD')
      config.app_id = ENV.fetch('FISHBOWL_APP_ID')
      config.app_name = ENV.fetch('FISHBOWL_APP_NAME', 'Fishbowl Ruby Gem')
      config.app_description = ENV.fetch('FISHBOWL_APP_DESCRIPTION', 'Ship diagnostic script')
      config.encode_password = %w[1 true yes].include?(ENV.fetch('FISHBOWL_ENCODE_PASSWORD', 'true').downcase)
      config.debug = %w[1 true yes].include?(ENV.fetch('FISHBOWL_DEBUG', 'false').downcase)
      config.mysql_url = ENV['FISHBOWL_MYSQL_URL']
    end
  end

  def connect!
    print 'Connecting to Fishbowl... '
    Fishbowl::Connection.connect
    puts 'OK'
  end

  def shipment(order_number, carrier = nil, tracking_number = nil)
    Fishbowl::Models::Shipping.new(
      order_number,
      carrier || ENV.fetch('FISHBOWL_CARRIER', 'H - FedEx Home Delivery'),
      tracking_number || ENV.fetch('FISHBOWL_TRACKING_NUMBER', '1234432556')
    )
  end

  def run_step(label)
    print "\n==> #{label}... "
    response = yield
    puts import_summary(response)
    dump_response(label, response)
    response
  rescue Fishbowl::Errors::StatusError, Fishbowl::Errors::RetryStatusError => e
    puts "FAILED (#{e.class})"
    warn e.message
    raise
  end

  def import_summary(response)
    msgs_rs = response.dig('FbiXml', 'FbiMsgsRs')
    import_code = import_status_code(response)
    envelope_code = msgs_rs&.fetch('@statusCode', nil)
    parts = []
    parts << "FbiMsgsRs=#{envelope_code}" if envelope_code
    parts << "ImportRs=#{import_code}" if import_code
    parts.empty? ? 'done' : parts.join(', ')
  end

  def import_status_code(response)
    import_rs = response.dig('FbiXml', 'FbiMsgsRs', 'ImportRs')
    return unless import_rs

    import_rs['@statusCode'] || import_rs['statusCode']
  end

  def dump_response(label, response)
    path = File.join(ROOT, 'tmp', "#{label.gsub(/\W+/, '_').downcase}_#{Time.now.to_i}.json")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(response))
    puts "   saved response: #{path}"
  end

  def query(sql)
    run_step('ExecuteQueryRq') do
      payload = Nokogiri::XML::Builder.new do |xml|
        xml.request do
          xml.ExecuteQueryRq do
            xml.Query sql
          end
        end
      end
      Fishbowl::Models::Base.send_request(payload, 'json')
    end
  end

  def print_query_rows(response)
    rows = response.dig('FbiXml', 'FbiMsgsRs', 'ExecuteQueryRs', 'Rows', 'Row')
    if rows.nil?
      puts '   (no rows)'
      return
    end

    rows = [rows] unless rows.is_a?(Array)
    rows.each_with_index do |row, index|
      puts "   row #{index + 1}: #{row}"
    end
  end

  def inspect_order(order_number)
    puts "\n--- Order snapshot: #{order_number} ---"

    [
      ["SO status", "SELECT so.num, so.statusId, so.carrierId FROM so WHERE so.num = '#{order_number}'"],
      ['Shipments', "SELECT ship.num, ship.statusId FROM ship JOIN so ON so.id = ship.soId WHERE so.num = '#{order_number}'"],
      ['Cartons', "SELECT shipcarton.num, shipcarton.trackingnum FROM shipcarton JOIN ship ON ship.id = shipcarton.shipId JOIN so ON so.id = ship.soId WHERE so.num = '#{order_number}'"]
    ].each do |label, sql|
      puts "\n#{label}:"
      response = query(sql)
      print_query_rows(response)
    end

    puts "\nLoadSORq:"
    load_response = Fishbowl::Models::SalesOrder.find(order_number, 'json')
    dump_response('load_so', load_response)
    status = load_response.dig('FbiXml', 'FbiMsgsRs', 'LoadSORs', 'SalesOrder', 'Status')
    puts "   SalesOrder.Status = #{status.inspect}"
  end

  def try_pick(order_number)
    puts "\n--- Try pick methods: #{order_number} ---"
    preflight(order_number)

    methods = [
      ['ImportPickingData Commit+Finish', -> { Fishbowl::Models::Picking.pick(order_number) }],
      ['SaveRq Pick Committed', -> { Fishbowl::Models::Picking.pick_via_save_rq(order_number) }],
      ['ImportPickingData PickNum', -> { Fishbowl::Models::Picking.pick_via_pick_num(order_number) }]
    ]

    methods.each do |label, call|
      snapshot = Fishbowl::Models::Shipping.order_snapshot(order_number)
      had_ship = snapshot[:ship_num]
      print "#{label}... "
      begin
        call.call
        snapshot = Fishbowl::Models::Shipping.order_snapshot(order_number)
        if snapshot[:ship_num] && snapshot[:ship_num] != had_ship
          puts "created shipment #{snapshot[:ship_num]} (SO statusId=#{snapshot[:status_id]})"
        else
          puts "ImportRs ok but no new shipment (SO statusId=#{snapshot[:status_id]})"
        end
      rescue StandardError => e
        puts "FAILED: #{e.message}"
      end
    end
  end

  def preflight(order_number)
    puts "\n--- Preflight: #{order_number} ---"
    snapshot = Fishbowl::Models::Shipping.order_snapshot(order_number)
    puts "SO statusId: #{snapshot[:status_id] || 'not found'}"
    puts "Shipment:    #{snapshot[:ship_num] || '(none yet)'}"
    puts "Ship status: #{snapshot[:ship_status_id] || 'n/a'}"

    case snapshot[:status_id]
    when '20'
      puts 'Ready for pick (Issued). Flow will Commit+Finish pick, then pack/track/ship.'
    when '25'
      puts 'In progress — shipment may already exist from a prior pick.'
    when '60'
      puts 'Already fulfilled.'
    else
      puts 'Unexpected status — verify in Fishbowl UI before shipping.'
    end

    snapshot
  end

  def help_text
    <<~HELP
      Commands:
        preflight ORDER_NUMBER             Check SO/shipment state before shipping
        inspect ORDER_NUMBER              Run diagnostic SQL + LoadSORq
        query "SQL..."                    Run arbitrary ExecuteQueryRq
        pick ORDER_NUMBER                 ImportPickingData (+ SaveRq fallback)
        finish ORDER [CARRIER] [TRACKING]  Pack/track/ship only (after manual pick in UI)
        try-pick ORDER_NUMBER             Test all pick methods and show results
        pack ORDER_NUMBER                 ImportPackingData
        track ORDER [CARRIER] [TRACKING]  ImportShipCartonTracking
        ship ORDER [CARRIER] [TRACKING]   ImportShippingData
        flow ORDER [CARRIER] [TRACKING]   Pick, pack, track, and ship
        flow ORDER --add-inventory ...  Add inventory first, then ship
        fulfill ORDER [CARRIER] [TRACKING]  Add inventory + flow (same as --add-inventory)
        headers                           Show official ImportRq column headers

      Credentials: copy .env.example -> .env (gitignored)
    HELP
  end
end

if __FILE__ == $PROGRAM_NAME
  ShipDiagnostic.load_dotenv!
  options = {}
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: ruby script/ship_diagnostic.rb COMMAND [ARGS]'
    opts.on('--add-inventory', 'Add inventory for SO line items before pick (flow/fulfill)') do
      options[:add_inventory] = true
    end
  end

  command = ARGV.shift
  parser.parse!(ARGV) if command != 'help'

  if command.nil? || command == 'help'
    puts ShipDiagnostic.help_text
    exit 0
  end

  ShipDiagnostic.configure_fishbowl!
  ShipDiagnostic.connect!

  case command
  when 'finish'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    shipment = ShipDiagnostic.shipment(order_number, ARGV[1], ARGV[2])
    ShipDiagnostic.preflight(order_number)
    puts "\nRunning pack/track/ship (pick skipped — order must already be picked in Fishbowl UI)..."
    Fishbowl::Models::Shipping.ship_existing(shipment)
    puts "\nDone. Re-inspecting order..."
    ShipDiagnostic.inspect_order(order_number)
  when 'try-pick'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    ShipDiagnostic.try_pick(order_number)
  when 'preflight'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    ShipDiagnostic.preflight(order_number)
  when 'inspect'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    ShipDiagnostic.inspect_order(order_number)
  when 'query'
    sql = ARGV.join(' ')
    abort 'Provide SQL in quotes' if sql.empty?

    response = ShipDiagnostic.query(sql)
    ShipDiagnostic.print_query_rows(response)
  when 'pick'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    ShipDiagnostic.run_step('pick') { Fishbowl::Models::Picking.pick(order_number) }
  when 'pack'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    ShipDiagnostic.run_step('pack') { Fishbowl::Models::Packing.pack(order_number) }
  when 'track'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    shipment = ShipDiagnostic.shipment(order_number, ARGV[1], ARGV[2])
    ShipDiagnostic.run_step('track') { Fishbowl::Models::CartonTracking.track(shipment) }
  when 'ship'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    shipment = ShipDiagnostic.shipment(order_number, ARGV[1], ARGV[2])
    ShipDiagnostic.run_step('ship') { Fishbowl::Models::Shipping.ship(shipment) }
  when 'headers'
    %w[ImportPickingData ImportPackingData ImportShipCartonTracking ImportShippingData ImportAddInventory].each do |type|
      puts "\n=== #{type} ==="
      p Fishbowl::Models::ImportRequest.headers(type)
    end
  when 'flow', 'fulfill'
    order_number = ARGV[0] || ENV.fetch('FISHBOWL_ORDER_NUMBER')
    shipment = ShipDiagnostic.shipment(order_number, ARGV[1], ARGV[2])
    add_inventory = options[:add_inventory] || command == 'fulfill'
    ShipDiagnostic.preflight(order_number)
    if add_inventory
      puts "\nAdding inventory for order line items..."
      ShipDiagnostic.run_step('add_inventory') do
        Fishbowl::Models::InventoryAdjustment.add_for_order(order_number)
      end
    end
    puts "\nRunning pick_and_ship..."
    Fishbowl::Models::Shipping.pick_and_ship(shipment)
    puts "\nDone. Re-inspecting order..."
    ShipDiagnostic.inspect_order(order_number)
  else
    abort "Unknown command: #{command}\n\n#{ShipDiagnostic.help_text}"
  end
end
