# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Step 1: finish pick via ImportPickingData (creates the shipment record).
    class Picking < Base
      ATTRIBUTES = %i[order_number action].freeze
      HEADERS = %w[OrderNumber Action].freeze
      ACTION_FINISH = 'Finish'

      attr_accessor(*ATTRIBUTES)

      def initialize(order_number, action: ACTION_FINISH)
        super
        @order_number = order_number.to_s.sub(/\AS/, '')
        @action = action
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

      def self.pick(orders, format = nil)
        picks = Array(orders).map { |order| coerce(order) }
        ImportRequest.create(ImportRequest::PICKING_DATA, [header_row, *picks], format)
      end

      def self.coerce(order)
        return order if order.is_a?(Picking)

        if order.is_a?(Shipping)
          new(order.order_number)
        elsif order.is_a?(Hash)
          new(
            order[:order_number] || order['order_number'],
            action: order[:action] || order['action'] || ACTION_FINISH
          )
        else
          new(order)
        end
      end
      private_class_method :coerce
    end
  end
end
