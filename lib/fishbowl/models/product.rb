# frozen_string_literal: true

require 'json'
module Fishbowl
  module Models
    class Product < Base
      # Find product description by sku
      def self.description(sku)
        all_descriptions[sku.to_s]
      end

      # All Products
      ALL_PRODUCTS = 'SELECT sku, description FROM PRODUCT WHERE activeFlag = TRUE'
      def self.all_descriptions
        @all_descriptions ||= format_sql(Fishbowl::Connection.query(ALL_PRODUCTS)).to_h do |product|
          [product['sku'], product['description']]
        end
      end
    end
  end
end
