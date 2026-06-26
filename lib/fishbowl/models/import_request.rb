# frozen_string_literal: true

require 'csv'
module Fishbowl
  module Models
    class ImportRequest < Base
      TYPES = [
        CUSTOMERS = 'ImportCustomers',
        SALES_ORDER = 'ImportSalesOrder',
        SALES_ORDER_DETAILS = 'ImportSalesOrderDetails',
        PICKING_DATA = 'ImportPickingData',
        SHIPPING_DATA = 'ImportShippingData'
      ].freeze

      def self.create(type, rows, format = nil)
        send_request(
          Nokogiri::XML::Builder.new do |xml|
            xml.request do
              xml.ImportRq do
                xml.Type type
                xml.Rows do
                  rows.map do |row|
                    xml.Row csv_row(row)
                  end
                end
              end
            end
          end, format || FORMAT
        )
      end

      def self.csv_row(row)
        row.is_a?(String) ? row : row.to_csv.chomp
      end
      private_class_method :csv_row

      def self.all(format = nil)
        send_request(
          Nokogiri::XML::Builder.new do |xml|
            xml.request do
              xml.ImportListRq
            end
          end, format || FORMAT
        )
      end

      def self.headers(type)
        data = send_request(
          Nokogiri::XML::Builder.new do |xml|
            xml.request do
              xml.ImportHeaderRq do
                xml.Type type
              end
            end
          end, 'json'
        )
        response = data.dig('FbiXml', 'FbiMsgsRs', 'ImportHeaderRs', 'Header', 'Row')
        response = response.join if response.is_a? Array
        CSV.parse(response).flatten
      end
    end
  end
end
