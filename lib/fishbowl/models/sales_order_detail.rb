# frozen_string_literal: true

require 'pry'
module Fishbowl
  module Models
    class SalesOrderDetail < Base
      ATTRIBUTES = %i[
        so_num status customer_name customer_contact bill_to_name bill_to_address bill_to_city bill_to_state bill_to_zip
        bill_to_country ship_to_name ship_to_address ship_to_city ship_to_state ship_to_zip ship_to_country
        ship_to_residential carrier_name tax_rate_name priority_id po_num vendor_po_num date salesman shipping_terms
        payment_terms fob note quick_books_class_name location_group_name order_date_scheduled url carrier_service
        date_expired phone email category cf_custom cf_opportunity_name cf_crm_code cf_crm_order_num
        cf_crm_shipments_exported cf_export_order_crm cf_crm_order_update_complete so_item_type_id product_number
        product_description product_quantity uom product_price taxable tax_code item_note item_quick_books_class_name
        item_date_scheduled show_item kit_item revision_level customer_part_number
      ].freeze

      attr_accessor(*ATTRIBUTES)

      def initialize(**args)
        super
        (args.keys & ATTRIBUTES).each { |key| send("#{key}=", args[key]) }
      end
      
      def add_address(address, city, state, zip, country: 'US', ship_to_residential: true)
        @bill_to_address      = @ship_to_address  = address
        @bill_to_city         = @ship_to_city     = city
        @bill_to_state        = @ship_to_state    = state
        @bill_to_zip          = @ship_to_zip      = zip
        @bill_to_country      = @ship_to_country  = country
        @ship_to_residential  = ship_to_residential
      end

      def add_ship_to_residential(ship_to_residential)
        @ship_to_residential  = ship_to_residential
      end

      def add_ship_to_address(name, address, city, state, zip, country: 'US', ship_to_residential: true)
        @ship_to_name         = name
        @ship_to_address      = address
        @ship_to_city         = city
        @ship_to_state        = state
        @ship_to_zip          = zip
        @ship_to_country      = country
        @ship_to_residential  = ship_to_residential
      end

      def add_bill_to_address(name, address, city, state, zip, country: 'US')
        @bill_to_name         = name
        @bill_to_address      = address
        @bill_to_city         = city
        @bill_to_state        = state
        @bill_to_zip          = zip
        @bill_to_country      = country
      end

      def add_notes(note)
        @note = note
      end

      def self.load_order(order_number)
        order = find(order_number).dig('FbiXml', 'FbiMsgsRs', 'LoadSORs', 'SalesOrder')
        new(so_num: order['Number'], status: order['Status'], customer_name: order['CustomerName'],
            customer_contact: order['CustomerContact'], bill_to_name: order['BillTo']['Name'],
            bill_to_address: order['BillTo']['AddressField'], bill_to_city: order['BillTo']['City'],
            bill_to_state: order['BillTo']['State'], bill_to_zip: order['BillTo']['Zip'],
            bill_to_country: order['BillTo']['Country'], ship_to_name: order['Ship']['Name'],
            ship_to_address: order['Ship']['AddressField'], ship_to_city: order['Ship']['City'],
            ship_to_state: order['Ship']['State'], ship_to_zip: order['Ship']['Zip'],
            ship_to_country: order['Ship']['Country'], carrier_name: order['Carrier'],
            tax_rate_name: order['TaxRateName'], priority_id: order['PriorityId'],
            salesman: order['Salesman'], shipping_terms: order['ShippingTerms'],
            payment_terms: order['PaymentTerms'], fob: order['FOB'], note: order['Note'],
            quick_books_class_name: order['QuickBooksClassName'], location_group_name: order['LocationGroup'],
            order_date_scheduled: order['DateScheduledFulfillment'], phone: order['Phone'], email: order['Email'],
            product_quantity: order['Quantity'], uom: order['UOMCode'], product_price: order['ProductPrice'],
            taxable: order['Taxable'])
      end

      def save
        ImportRequest.create(ImportRequest::SALES_ORDER_DETAILS, [self])
      end

      def self.find(order_number, format = nil)
        raise Fishbowl::Errors.ArgumentError if order_number.nil?

        request = load_order_request(order_number)
        send_request(request, format || FORMAT)
      end

      def self.load_order_request(order_number)
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.LoadSORq do
              xml.Number order_number.to_s
            end
          end
        end
      end
    end
  end
end
