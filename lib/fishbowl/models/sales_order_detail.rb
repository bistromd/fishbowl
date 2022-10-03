# frozen_string_literal: true

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

      def upsert
        ImportRequest.create(ImportRequest::SALES_ORDER_DETAILS, [self])
      end
    end
  end
end
