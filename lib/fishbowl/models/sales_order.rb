# frozen_string_literal: true

module Fishbowl
  module Models
    class SalesOrder < Base
      ATTRIBUTES = %i[flag so_num status customer_name customer_contact bill_to_name bill_to_address
                      bill_to_city bill_to_state bill_to_zip bill_to_country ship_to_name ship_to_address
                      ship_to_city ship_to_state ship_to_zip ship_to_country ship_to_residential carrier_name
                      tax_rate_name priority_id po_num vendor_po_num date salesman shipping_terms
                      payment_terms fob note quick_books_class_name location_group_name order_date_scheduled
                      url carrier_service date_expired phone email category cf_custom cf_opportunity_name
                      cf_crm_code cf_crm_order_num cf_crm_shipments_exported cf_export_order_crm
                      cf_crm_order_update_complete_flag so_item_type_id product_number product_description
                      product_quantity uom product_price taxable tax_code note item_quick_books_class_name
                      item_date_scheduled show_item kit_item revision_level customer_part_number].freeze
      attr_accessor(*ATTRIBUTES)

      ORDER_STATUSES          = [ESTIMATE = 10, ISSUED = 20, IN_PROGRESS = 25, FULFILLED = 60, VOID = 80].freeze
      CARRIER_NAME            = 'H - FedEx Home Delivery'
      SHIPPING_TERMS          = 'Prepaid'
      FOB                     = 'Origin'
      SALES_ORDER             = 'SO'
      SALES_ORDER_ITEM        = 'ITEM'
      NONE                    = 'None'
      TAX_CODE                = 'NON'

      def initialize(number, customer_name, location_group_name, note, status = ESTIMATE)
        super
        @so_num                 = number
        @customer_contact       = @bill_to_name = @ship_to_name = @customer_name = customer_name
        @location_group_name    = location_group_name
        @status                 = status
        @note                   = note
        @shipping_terms         = @payment_terms = SHIPPING_TERMS
        @carrier_name           = CARRIER_NAME
        @fob                    = FOB
        @flag                   = SALES_ORDER
        @tax_rate_name          = NONE
        @tax_code               = TAX_CODE
        @quick_books_class_name = NONE

        @taxable                = false
        @show_item              = true
        @kit_item               = false
        @price                  = 0.00
      end

      def add_fulfillment_date(date)
        @order_date_scheduled = date
      end

      def add_address(address, city, state, zip, country = 'US')
        @bill_to_address      = @ship_to_address  = address
        @bill_to_city         = @ship_to_city     = city
        @bill_to_state        = @ship_to_state    = state
        @bill_to_zip          = @ship_to_zip      = zip
        @bill_to_country      = @ship_to_country  = country
        @ship_to_residential  = true
      end

      def add_ship_to_residential(ship_to_residential)
        @ship_to_residential  = ship_to_residential
      end

      def add_ship_to_address(address, city, state, zip, country = 'US')
        @ship_to_address      = address
        @ship_to_city         = city
        @ship_to_state        = state
        @ship_to_zip          = zip
        @ship_to_country      = country
        @ship_to_residential  = yes
      end

      def add_bill_to_address(address, city, state, zip, country = 'US')
        @bill_to_address      = address
        @bill_to_city         = city
        @bill_to_state        = state
        @bill_to_zip          = zip
        @bill_to_country      = country
      end

      def add_items(items)
        @items = items
      end

      def create
        ImportRequest.create(ImportRequest::SALES_ORDER, [self])
      end

      def save
        Base.send_request(order_request, FORMAT)
      end

      def self.find(order_number, format = nil)
        raise Fishbowl::Errors.ArgumentError if order_number.nil?

        request = load_order_request(order_number)
        send_request(request, format || FORMAT)
      end

      def self.save(data)
        request = save_order_request(data)
        send_request(request, format || FORMAT)
      end

      def self.issue(order_number, format = nil)
        raise Fishbowl::Errors.ArgumentError if order_number.nil?

        request = issue_order_request(order_number)
        send_request(request, format || FORMAT)
      end

      def self.void(order_number, format = nil)
        raise Fishbowl::Errors.ArgumentError if order_number.nil?

        request = void_order_request(order_number)
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

      def self.issue_order_request(order_number)
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.IssueSORq do
              xml.SONumber order_number.to_s
            end
          end
        end
      end

      def self.void_order_request(order_number)
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.VoidSORq do
              xml.SONumber order_number.to_s
            end
          end
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      # rubocop:disable Metrics/BlockLength
      # rubocop:disable Metrics/MethodLength
      def order_request
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.SOSaveRq do
              xml.SalesOrder do
                xml.Number so_num unless so_num.nil?
                xml.Salesman salesman unless salesman.nil?
                xml.CustomerName customer_name unless customer_name.nil?
                xml.CustomerContact customer_contact unless customer_contact.nil?
                xml.Status status unless status.nil?
                xml.Carrier carrier_name unless carrier_name.nil?
                xml.PaymentTerms payment_terms unless payment_terms.nil?
                xml.CustomerPO po_num unless po_num.nil?
                xml.VendorPO vendor_po_num unless vendor_po_num.nil?
                xml.QuickBooksClassName quick_books_class_name unless quick_books_class_name.nil?
                xml.FirstShipDate order_date_scheduled unless order_date_scheduled.nil?
                xml.BillTo do
                  xml.Name bill_to_name unless bill_to_name.nil?
                  xml.AddressField bill_to_address unless bill_to_address.nil?
                  xml.City bill_to_city unless bill_to_city.nil?
                  xml.Zip bill_to_zip unless bill_to_zip.nil?
                  xml.Country bill_to_country unless bill_to_country.nil?
                  xml.State bill_to_state unless bill_to_state.nil?
                end
                xml.Ship do
                  xml.Name ship_to_name unless ship_to_name.nil?
                  xml.AddressField ship_to_address unless ship_to_address.nil?
                  xml.City ship_to_city unless ship_to_city.nil?
                  xml.Zip ship_to_zip unless ship_to_zip.nil?
                  xml.Country ship_to_country unless ship_to_country.nil?
                  xml.State ship_to_state unless ship_to_state.nil?
                end
                unless @items.nil?
                  xml.Items do
                    @items.each do |item|
                      xml.SalesOrderItem do
                        xml.ID item.id unless item.id.nil?
                        xml.ProductNumber item.product_number unless item.product_number.nil?
                        xml.ProductPrice item.product_price unless item.product_price.nil?
                        xml.TotalPrice item.total_price unless item.total_price.nil?
                        xml.Quantity item.quantity unless item.quantity.nil?
                        xml.UOMCode item.uom_code unless item.uom_code.nil?
                        xml.Description item.description unless item.description.nil?
                        xml.LineNumber item.line_number unless item.line_number.nil?
                        xml.QuickBooksClassName item.quick_books_class_name unless item.quick_books_class_name.nil?
                        xml.NewItemFlag 'false'
                        xml.DateScheduledFulfillment order_date_scheduled unless order_date_scheduled.nil?
                        xml.ItemType item.item_type || '10'
                        xml.Status '10'
                        xml.AdjustPercentage item.adjust_percentage unless item.adjust_percentage.nil?
                      end
                    end
                  end
                end
              end
              xml.IssueFlag 'false'
              xml.IgnoreItems 'false'
            end
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/CyclomaticComplexity
    end
  end
end
