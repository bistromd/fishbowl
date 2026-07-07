# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Step 3: attach tracking to a packed carton via ImportShipCartonTracking.
    class CartonTracking < Base
      ATTRIBUTES = %i[order_number carton_num tracking_num].freeze
      HEADERS = %w[OrderNumber CartonNum TrackingNum].freeze
      DEFAULT_CARTON_NUM = '1'

      attr_accessor(*ATTRIBUTES)

      def initialize(order_number, tracking_num, carton_num: DEFAULT_CARTON_NUM)
        super
        @order_number = order_number.to_s.sub(/\AS/, '')
        @tracking_num = tracking_num
        @carton_num = carton_num.to_s
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

      def self.track(shipments, format = nil)
        rows = Array(shipments).map { |shipment| coerce(shipment) }
        ImportRequest.create(ImportRequest::SHIP_CARTON_TRACKING, [header_row, *rows], format)
      end

      def self.coerce(shipment)
        return shipment if shipment.is_a?(CartonTracking)

        if shipment.is_a?(Shipping)
          new(shipment.order_number, shipment.tracking_number, carton_num: shipment.carton_num)
        elsif shipment.is_a?(Hash)
          new(
            shipment[:order_number] || shipment['order_number'],
            shipment[:tracking_number] || shipment['tracking_number'] || shipment[:tracking_num] || shipment['tracking_num'],
            carton_num: shipment[:carton_num] || shipment['carton_num'] || DEFAULT_CARTON_NUM
          )
        else
          order_number, tracking_num, carton_num = shipment
          new(order_number, tracking_num, carton_num: carton_num || DEFAULT_CARTON_NUM)
        end
      end
      private_class_method :coerce
    end
  end
end
