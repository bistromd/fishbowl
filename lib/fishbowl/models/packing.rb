# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Step 2: pack via ImportPackingData (column: SONum).
    class Packing < Base
      ATTRIBUTES = %i[so_num].freeze
      HEADERS = %w[SONum].freeze

      attr_accessor :so_num

      def initialize(so_num)
        super
        @so_num = so_num.to_s.sub(/\AS/, '')
      end

      def to_csv
        self.class.quoted_csv_row([so_num])
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

        number = case order
                 when Shipping then order.order_number
                 when Hash then order[:so_num] || order['so_num'] || order[:order_number] || order['order_number']
                 else order
                 end
        new(number)
      end
      private_class_method :coerce
    end
  end
end
