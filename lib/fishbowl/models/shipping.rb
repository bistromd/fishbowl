# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Self-contained auto-ship via ImportShippingData — no pre-existing pick record required.
    class Shipping < Base
      ATTRIBUTES = %i[ship_num carrier tracking_number status carton_num fulfill item quantity].freeze
      HEADERS = %w[ShipNum Carrier TrackingNumber Status CartonNum Fulfill Item Quantity].freeze
      STATUS_SHIPPED = 'Shipped'
      DEFAULT_CARTON_NUM = '1'
      DEFAULT_FULFILL = 'true'
      DEFAULT_QUANTITY = '1'

      attr_accessor :order_number, :carrier, :tracking_number, :status, :carton_num, :fulfill, :item, :quantity

      def initialize(order_number, carrier, tracking_number, item:, quantity: DEFAULT_QUANTITY,
                     status: STATUS_SHIPPED, carton_num: DEFAULT_CARTON_NUM, fulfill: DEFAULT_FULFILL)
        super
        @order_number = order_number.to_s.sub(/\AS/, '')
        @carrier = carrier
        @tracking_number = tracking_number
        @item = item
        @quantity = quantity.to_s
        @status = status
        @carton_num = carton_num
        @fulfill = fulfill
      end

      def ship_num
        "S#{order_number}"
      end

      def to_csv
        self.class.quoted_csv_row(ATTRIBUTES.map { |attribute| send(attribute) })
      end

      def self.quoted_csv_row(values)
        CSV.generate_line(values, force_quotes: true).chomp
      end

      def self.header_row
        HEADERS.join(',')
      end

      def self.ship(shipments, format = nil)
        shipment_rows = Array(shipments).map { |shipment| coerce(shipment) }
        ImportRequest.create(
          ImportRequest::SHIPPING_DATA,
          [header_row, *shipment_rows],
          format
        )
      end

      def self.pick_and_ship(shipments, format = nil)
        shipment_rows = Array(shipments).map { |shipment| coerce(shipment) }
        Picking.import(shipment_rows, format)
        ship(shipment_rows, format)
      end

      def self.coerce(shipment)
        return shipment if shipment.is_a?(Shipping)

        if shipment.is_a?(Hash)
          new(
            shipment[:order_number] || shipment['order_number'],
            shipment[:carrier] || shipment['carrier'],
            shipment[:tracking_number] || shipment['tracking_number'],
            item: shipment[:item] || shipment['item'],
            quantity: shipment[:quantity] || shipment['quantity'] || DEFAULT_QUANTITY,
            status: shipment[:status] || shipment['status'] || STATUS_SHIPPED,
            carton_num: shipment[:carton_num] || shipment['carton_num'] || DEFAULT_CARTON_NUM,
            fulfill: shipment[:fulfill] || shipment['fulfill'] || DEFAULT_FULFILL
          )
        else
          order_number, carrier, tracking_number, item, quantity = shipment
          new(
            order_number,
            carrier,
            tracking_number,
            item: item,
            quantity: quantity || DEFAULT_QUANTITY
          )
        end
      end
      private_class_method :coerce
    end
  end
end
