# frozen_string_literal: true

module Fishbowl
  module Models
    # Step 1: commit a pick via SaveRq.
    class Picking < Base
      TYPE_SO = 'SO'
      STATUS_COMMITTED = 'Committed'

      attr_accessor :order_number, :type, :status

      def initialize(order_number, type: TYPE_SO, status: STATUS_COMMITTED)
        super
        @order_number = order_number
        @type = type
        @status = status
      end

      def self.pick(orders, format = nil)
        Array(orders).map { |order| pick_one(coerce(order), format) }
      end

      def self.pick_one(pick, format = nil)
        send_request(pick_request(pick), format || FORMAT)
      end

      def self.pick_request(pick)
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.SaveRq do
              xml.Pick do
                xml.OrderNumber pick.order_number.to_s
                xml.Type pick.type
                xml.Status pick.status
              end
            end
          end
        end
      end

      def self.coerce(order)
        return order if order.is_a?(Picking)

        if order.is_a?(Shipping)
          new(order.order_number)
        elsif order.is_a?(Hash)
          new(
            order[:order_number] || order['order_number'],
            type: order[:type] || order['type'] || TYPE_SO,
            status: order[:status] || order['status'] || STATUS_COMMITTED
          )
        else
          new(order)
        end
      end
      private_class_method :coerce
    end
  end
end
