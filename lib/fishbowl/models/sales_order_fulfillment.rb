# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Fulfill and complete a sales order via ImportSalesOrder.
    class SalesOrderFulfillment < Base
      ATTRIBUTES = %i[flag order_number status carrier_name item_number item_quantity].freeze
      HEADERS = %w[Flag OrderNumber Status CarrierName ItemNumber ItemQuantity].freeze
      FLAG = 'SO'
      STATUS_COMPLETED = '95'

      attr_accessor(*ATTRIBUTES)

      def initialize(order_number, carrier_name, item_number, item_quantity: 1, status: STATUS_COMPLETED)
        super
        @flag = FLAG
        @order_number = order_number
        @status = status.to_s
        @carrier_name = carrier_name
        @item_number = item_number
        @item_quantity = item_quantity.to_s
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

      def self.import(fulfillments, format = nil)
        rows = [header_row] + Array(fulfillments).map { |fulfillment| coerce(fulfillment) }
        ImportRequest.create(ImportRequest::SALES_ORDER, rows, format)
      end

      def self.coerce(fulfillment)
        return fulfillment if fulfillment.is_a?(SalesOrderFulfillment)

        if fulfillment.is_a?(Hash)
          new(
            fulfillment[:order_number] || fulfillment['order_number'],
            fulfillment[:carrier_name] || fulfillment['carrier_name'] || fulfillment[:carrier] || fulfillment['carrier'],
            fulfillment[:item_number] || fulfillment['item_number'] || fulfillment[:item] || fulfillment['item'],
            item_quantity: fulfillment[:item_quantity] || fulfillment['item_quantity'] || fulfillment[:quantity] || fulfillment['quantity'] || 1,
            status: fulfillment[:status] || fulfillment['status'] || STATUS_COMPLETED
          )
        else
          order_number, carrier_name, item_number, item_quantity, status = fulfillment
          new(
            order_number,
            carrier_name,
            item_number,
            item_quantity: item_quantity || 1,
            status: status || STATUS_COMPLETED
          )
        end
      end
      private_class_method :coerce
    end
  end
end
