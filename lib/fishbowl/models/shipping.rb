# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Step 2: ship a picked order via ImportShippingData.
    class Shipping < Base
      ATTRIBUTES = %i[ship_num carrier tracking_number status].freeze
      HEADERS = %w[ShipNum Carrier TrackingNumber Status].freeze
      STATUS_SHIPPED = 'Shipped'

      attr_accessor :order_number, :carrier, :tracking_number, :status

      def initialize(order_number, carrier, tracking_number, status: STATUS_SHIPPED)
        super
        @order_number = order_number.to_s.sub(/\AS/, '')
        @carrier = carrier
        @tracking_number = tracking_number
        @status = status
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
            status: shipment[:status] || shipment['status'] || STATUS_SHIPPED
          )
        else
          order_number, carrier, tracking_number, status = shipment
          new(order_number, carrier, tracking_number, status: status || STATUS_SHIPPED)
        end
      end
      private_class_method :coerce
    end
  end
end
