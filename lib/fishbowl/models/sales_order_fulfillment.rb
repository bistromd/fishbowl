# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Fulfill and ship a sales order via ImportSalesOrder.
    class SalesOrderFulfillment < Base
      ATTRIBUTES = %i[flag order_number status carrier_name item_number item_quantity carton_number tracking_number].freeze
      HEADERS = %w[Flag OrderNumber Status CarrierName ItemNumber ItemQuantity CartonNumber TrackingNumber].freeze
      FLAG = 'SO'
      STATUS_FULFILLED = 'Fulfilled'
      DEFAULT_CARTON_NUMBER = '1'

      attr_accessor(*ATTRIBUTES)

      def initialize(order_number, carrier_name, item_number, tracking_number, item_quantity: 1,
                     carton_number: DEFAULT_CARTON_NUMBER, status: STATUS_FULFILLED)
        super
        @flag = FLAG
        @order_number = order_number
        @status = status
        @carrier_name = carrier_name
        @item_number = item_number
        @item_quantity = item_quantity.to_s
        @carton_number = carton_number.to_s
        @tracking_number = tracking_number
      end

      def to_csv
        self.class.quoted_csv_row(ATTRIBUTES.map { |attribute| send(attribute) })
      end

      def self.quoted_csv_row(values)
        CSV.generate_line(values, force_quotes: true).chomp
      end

      def self.import(fulfillments, format = nil)
        rows = [quoted_csv_row(HEADERS)] + Array(fulfillments).map { |fulfillment| coerce(fulfillment) }
        ImportRequest.create(ImportRequest::SALES_ORDER, rows, format)
      end

      def self.coerce(fulfillment)
        return fulfillment if fulfillment.is_a?(SalesOrderFulfillment)

        if fulfillment.is_a?(Hash)
          new(
            fulfillment[:order_number] || fulfillment['order_number'],
            fulfillment[:carrier_name] || fulfillment['carrier_name'] || fulfillment[:carrier] || fulfillment['carrier'],
            fulfillment[:item_number] || fulfillment['item_number'] || fulfillment[:item] || fulfillment['item'],
            fulfillment[:tracking_number] || fulfillment['tracking_number'],
            item_quantity: fulfillment[:item_quantity] || fulfillment['item_quantity'] || fulfillment[:quantity] || fulfillment['quantity'] || 1,
            carton_number: fulfillment[:carton_number] || fulfillment['carton_number'] || DEFAULT_CARTON_NUMBER,
            status: fulfillment[:status] || fulfillment['status'] || STATUS_FULFILLED
          )
        else
          order_number, carrier_name, item_number, tracking_number, item_quantity, carton_number = fulfillment
          new(
            order_number,
            carrier_name,
            item_number,
            tracking_number,
            item_quantity: item_quantity || 1,
            carton_number: carton_number || DEFAULT_CARTON_NUMBER
          )
        end
      end
      private_class_method :coerce
    end
  end
end
