# frozen_string_literal: true

require 'json'
module Fishbowl
  module Models
    class Customer < Base
      ATTRIBUTES = %i[name address_name address_contact address_type is_default address city
                      state zip country residential main home work mobile fax email pager
                      web other group credit_limit status active tax_rate salesman default_priority
                      number payment_terms tax_exempt tax_exempt_number url carrier_name carrier_service
                      shipping_terms alert_notes quick_books_class_name to_be_emailed to_be_printed
                      issuable_status cf_substitutions cf_free_shipping cf_shipping_type cf_ice cf_notes
                      cf_fraudaulent_sale cf_program_type].freeze
      attr_accessor(*ATTRIBUTES)

      STATUSES              = [NORMAL = 'Normal'].freeze
      ADDRESS_NAME          = [SHIP_ADDRESS_NAME = 'Shipping Address',
                               BILL_ADDRESS_NAME = 'Billing Address',
                               MAIN_ADDRESS_NAME = 'Main Address'].freeze
      ADDRESS_CONTACT       = 'Main Office'
      MAIN_OFFICE_TYPE      = 50
      PAYMENT_TERM_PREPAID  = 'Prepaid'
      SHIPPING_TYPE         = 'FedEx'

      def initialize(number, name, email)
        super
        @number = number
        # Limit name to 40 chars
        @name = name[0...39]
        @email = email
        @status = NORMAL
        @active = true
        @payment_terms = PAYMENT_TERM_PREPAID
      end

      def add_address(address, city, state, zip, country = 'US')
        @address = address
        @city = city
        @state = state
        @zip = zip
        @country = country
        @is_default = true
        @address_name = SHIP_ADDRESS_NAME
        @address_type = MAIN_OFFICE_TYPE
        @address_contact = name || ADDRESS_CONTACT
        @residential = true
      end

      def add_custom_fields(ice, free_shipping_boolean, program_type, notes = 'Automated')
        @cf_ice = ice
        @cf_free_shipping = free_shipping_boolean
        @cf_program_type = program_type
        @cf_shipping_type = SHIPPING_TYPE
        @cf_notes = notes
        @cf_substitutions = 'None'
      end

      def save
        ImportRequest.create(ImportRequest::CUSTOMERS, [self])
      end

      # Find customer by id
      FIND_CUSTOMER = 'SELECT * FROM CUSTOMER WHERE number=? LIMIT 1'
      def self.find(number)
        format_sql(
          Fishbowl::Connection.prepare(FIND_CUSTOMER, [number])
        ).last
      end

      # Find customer by name
      def self.find_name(name, format = nil)
        raise Fishbowl::Errors.ArgumentError if name.nil?

        request = load_customer_request(name)
        send_request(request, format || FORMAT)
      end

      def self.load_customer_request(name)
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.CustomerGetRq do
              xml.Name name
            end
          end
        end
      end
    end
  end
end
