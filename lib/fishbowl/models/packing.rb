# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Step 2: pack picked items into a carton via ImportPackingData.
    class Packing < Base
      ATTRIBUTES = %i[order_number carton_num].freeze
      HEADERS = %w[OrderNumber CartonNum].freeze
      DEFAULT_CARTON_NUM = '1'

      attr_accessor(*ATTRIBUTES)

      def initialize(order_number, carton_num: DEFAULT_CARTON_NUM)
        super
        @order_number = order_number.to_s.sub(/\AS/, '')
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

      def self.pack(orders, format = nil)
        packs = Array(orders).map { |order| coerce(order) }
        ImportRequest.create(ImportRequest::PACKING_DATA, [header_row, *packs], format)
      end

      def self.coerce(order)
        return order if order.is_a?(Packing)

        if order.is_a?(Shipping)
          new(order.order_number, carton_num: order.carton_num)
        elsif order.is_a?(Hash)
          new(
            order[:order_number] || order['order_number'],
            carton_num: order[:carton_num] || order['carton_num'] || DEFAULT_CARTON_NUM
          )
        else
          new(order)
        end
      end
      private_class_method :coerce
    end
  end
end
