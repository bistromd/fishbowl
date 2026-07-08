# frozen_string_literal: true

require 'csv'
require 'date'

module Fishbowl
  module Models
    # Step 4: close shipment via ImportShippingData.
    class Shipping < Base
      ATTRIBUTES = %i[ship_num ship_date carrier carrier_service].freeze
      HEADERS = ['ShipNum', 'Date', 'Carrier', 'Carrier Service'].freeze
      DEFAULT_CARTON_NUM = '1'

      attr_accessor :order_number, :carrier, :tracking_number, :ship_date, :carrier_service, :carton_num

      def initialize(order_number, carrier, tracking_number, ship_date: Date.today.strftime('%Y-%m-%d'),
                     carrier_service: '', carton_num: DEFAULT_CARTON_NUM)
        super
        @order_number = order_number.to_s.sub(/\AS/, '')
        @carrier = carrier
        @tracking_number = tracking_number
        @ship_date = ship_date
        @carrier_service = carrier_service
        @carton_num = carton_num.to_s
      end

      def ship_num
        "S#{order_number}"
      end

      def to_csv
        self.class.quoted_csv_row([ship_num, ship_date, carrier, carrier_service])
      end

      def self.quoted_csv_row(values)
        CSV.generate_line(values, force_quotes: true).chomp
      end

      def self.header_row
        'ShipNum,Date,Carrier,Carrier Service'
      end

      def self.ship(shipments, format = nil)
        shipment_rows = Array(shipments).map { |shipment| coerce(shipment) }
        ImportRequest.create(ImportRequest::SHIPPING_DATA, [header_row, *shipment_rows], format)
      end

      def self.ship_existing(shipments, format = nil)
        shipment_rows = Array(shipments).map { |shipment| coerce(shipment) }
        shipment_rows.each { |row| verify_shipment_created!(row.order_number) }
        Packing.pack(shipment_rows, format)
        CartonTracking.track(shipment_rows, format)
        ship(shipment_rows, format)
      end

      def self.pick_and_ship(shipments, format = nil, add_inventory: false)
        shipment_rows = Array(shipments).map { |shipment| coerce(shipment) }
        shipment_rows.each do |row|
          if add_inventory
            InventoryAdjustment.add_for_order(row.order_number, format: format)
          end
          Picking.ensure_shipment!(row.order_number, format)
          verify_shipment_created!(row.order_number)
        end
        Packing.pack(shipment_rows, format)
        CartonTracking.track(shipment_rows, format)
        ship(shipment_rows, format)
      end

      def self.verify_shipment_created!(order_number)
        return if shipment_exists?(order_number)

        snapshot = order_snapshot(order_number)
        raise Fishbowl::Errors::StatusError,
              "Pick returned success but no shipment record exists for order #{order_number} " \
              "(SO statusId=#{snapshot[:status_id] || 'unknown'}). " \
              "This usually means insufficient inventory in the order's location group. Try:\n" \
              "  ruby script/add_inventory_to_order_items.rb #{order_number}\n" \
              "  ruby script/ship_diagnostic.rb flow #{order_number} --add-inventory [CARRIER] [TRACKING]\n" \
              "Or pick manually in Fishbowl UI, then:\n" \
              "  ruby script/ship_diagnostic.rb finish #{order_number} [CARRIER] [TRACKING]"
      end

      def self.order_snapshot(order_number)
        so_row = query_rows("SELECT so.num, so.statusId FROM so WHERE so.num = '#{sanitize_sql(order_number)}'")[1]
        ship_row = query_rows(
          "SELECT ship.num, ship.statusId FROM ship " \
          "JOIN so ON so.id = ship.soId WHERE so.num = '#{sanitize_sql(order_number)}'"
        )[1]
        {
          status_id: so_row&.split(',')&.dig(1)&.delete('"'),
          ship_num: ship_row&.split(',')&.dig(0)&.delete('"'),
          ship_status_id: ship_row&.split(',')&.dig(1)&.delete('"')
        }
      end

      def self.shipment_exists?(order_number)
        sql = "SELECT ship.num FROM ship JOIN so ON so.id = ship.soId WHERE so.num = '#{sanitize_sql(order_number)}'"
        query_rows(sql).length > 1
      end

      def self.query_rows(sql)
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.ExecuteQueryRq do
              xml.Query sql
            end
          end
        end
        response = send_request(payload, FORMAT)
        rows = response.dig('FbiXml', 'FbiMsgsRs', 'ExecuteQueryRs', 'Rows', 'Row')
        return [] if rows.nil?

        rows.is_a?(Array) ? rows : [rows]
      end

      def self.sanitize_sql(value)
        value.to_s.gsub("'", "''")
      end
      private_class_method :sanitize_sql

      def self.coerce(shipment)
        return shipment if shipment.is_a?(Shipping)

        if shipment.is_a?(Hash)
          new(
            shipment[:order_number] || shipment['order_number'],
            shipment[:carrier] || shipment['carrier'],
            shipment[:tracking_number] || shipment['tracking_number'],
            ship_date: shipment[:ship_date] || shipment['ship_date'] || Date.today.strftime('%Y-%m-%d'),
            carrier_service: shipment[:carrier_service] || shipment['carrier_service'] || '',
            carton_num: shipment[:carton_num] || shipment['carton_num'] || DEFAULT_CARTON_NUM
          )
        else
          order_number, carrier, tracking_number, ship_date, carrier_service, carton_num = shipment
          new(
            order_number,
            carrier,
            tracking_number,
            ship_date: ship_date || Date.today.strftime('%Y-%m-%d'),
            carrier_service: carrier_service || '',
            carton_num: carton_num || DEFAULT_CARTON_NUM
          )
        end
      end
      private_class_method :coerce
    end
  end
end
