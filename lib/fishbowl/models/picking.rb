# frozen_string_literal: true

module Fishbowl
  module Models
    # Step 1: auto-pick a sales order via ImportPickingData.
    class Picking < Base
      ATTRIBUTES = %i[order_number action].freeze
      HEADERS = %w[OrderNumber Action].freeze
      ACTION_COMMIT = 'Commit'

      attr_accessor(*ATTRIBUTES)

      def initialize(order_number, action: ACTION_COMMIT)
        super
        @order_number = order_number
        @action = action
      end

      def self.import(orders, format = nil)
        rows = [HEADERS.to_csv.chomp] + Array(orders).map { |order| coerce(order) }
        ImportRequest.create(ImportRequest::PICKING_DATA, rows, format)
      end

      def self.coerce(order)
        return order if order.is_a?(Picking)

        if order.is_a?(Shipping)
          new(order.order_number)
        elsif order.is_a?(Hash)
          new(
            order[:order_number] || order['order_number'],
            action: order[:action] || order['action'] || ACTION_COMMIT
          )
        else
          new(order)
        end
      end
      private_class_method :coerce
    end
  end
end
