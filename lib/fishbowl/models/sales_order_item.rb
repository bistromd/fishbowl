# frozen_string_literal: true

module Fishbowl
  module Models
    class SalesOrderItem < Base
      ATTRIBUTES = %i[id product_number product_price total_price quantity uom_code description
                      line_number quick_books_class_name item_type adjust_percentage].freeze
      attr_accessor(*ATTRIBUTES)

      ITEM_TYPE       = 10
      UOM_CODE        = 'ea'
      NONE            = 'None'

      def initialize(sku, quantity = 1, line_number = nil)
        super
        @item_type              = ITEM_TYPE
        @uom_code               = UOM_CODE
        @product_price          = @total_price = 0.00
        @quick_books_class_name = NONE
        @product_number         = sku
        @description            = Product.description(sku)
        @quantity               = quantity
        @line_number            = line_number

        # args.slice(*ATTRIBUTES).each { |key, value| send("#{key}=", value) }
      end

      def self.items(sku_quantity_hash)
        line_number = 0
        sku_quantity_hash.map do |sku, quantity|
          new(sku, quantity, line_number += 1)
        end
      end
    end
  end
end
