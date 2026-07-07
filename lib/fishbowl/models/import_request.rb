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
        PACKING_DATA = 'ImportPackingData',
        SHIP_CARTON_TRACKING = 'ImportShipCartonTracking',
        SHIPPING_DATA = 'ImportShippingData'
      ].freeze

      def self.create(type, rows, format = nil)
        response = send_request(
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
        confirm_import_success!(response)
        response
      end

      def self.confirm_import_success!(response)
        status_code = import_status_code(response)
        raise Fishbowl::Errors::StatusError, 'Missing ImportRs statusCode in Fishbowl response' if status_code.nil?

        Fishbowl::Errors.confirm_success_or_raise(status_code)
      end

      def self.import_status_code(response)
        case response
        when Nokogiri::XML::Document, Nokogiri::XML::Element
          response.at_xpath('//*[local-name()="ImportRs"]/@statusCode')&.value
        else
          import_rs = response.dig('FbiXml', 'FbiMsgsRs', 'ImportRs')
          return unless import_rs

          import_rs['@statusCode'] || import_rs['statusCode']
        end
      end

      def self.csv_row(row)
        row.is_a?(String) ? row : row.to_csv
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
