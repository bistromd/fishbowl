# frozen_string_literal: true

require 'csv'

module Fishbowl
  module Models
    # Step 1: finish pick via ImportPickingData.
    # Note: ImportHeaderRq reports PickNum, but OrderNumber+Action Finish
    # is what creates the shipment record on this Fishbowl version.
    class Picking < Base
      ATTRIBUTES = %i[order_number action].freeze
      HEADERS = %w[OrderNumber Action].freeze
      ACTION_COMMIT = 'Commit'
      ACTION_FINISH = 'Finish'
      ACTIONS = [ACTION_COMMIT, ACTION_FINISH].freeze

      attr_accessor(*ATTRIBUTES)

      def initialize(order_number, action: ACTION_FINISH)
        super
        @order_number = order_number.to_s.sub(/\AS/, '')
        @action = action
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

      def self.pick(orders, format = nil)
        Array(orders).map { |order| pick_one(coerce(order), format) }.last
      end

      def self.pick_one(pick, format = nil)
        ACTIONS.each do |action|
          pick.action = action
          ImportRequest.create(ImportRequest::PICKING_DATA, [header_row, pick], format)
        end
      end

      def self.pick_via_save_rq(order_number, format = nil, status: 'Committed')
        send_request(save_rq_pick(order_number, status), format || FORMAT)
      end

      def self.pick_via_pick_num(order_number, format = nil)
        pick = new(order_number)
        ImportRequest.create(
          ImportRequest::PICKING_DATA,
          [pick_num_header_row, quoted_csv_row([pick.order_number])],
          format
        )
      end

      def self.ensure_shipment!(order_number, format = nil)
        number = order_number.to_s.sub(/\AS/, '')
        return if Shipping.shipment_exists?(number)

        pick(number, format)
        return if Shipping.shipment_exists?(number)

        begin
          pick_via_save_rq(number, format, status: 'Committed')
        rescue Fishbowl::Errors::StatusError => e
          raise unless unsupported_pick_save_rq?(e)
        end
        return if Shipping.shipment_exists?(number)

        pick_via_pick_num(number, format)
      end

      def self.unsupported_pick_save_rq?(error)
        error.message.include?('Unknown request function')
      end
      private_class_method :unsupported_pick_save_rq?

      def self.pick_num_header_row
        'PickNum'
      end

      def self.save_rq_pick(order_number, status)
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.SaveRq do
              xml.Pick do
                xml.OrderNumber order_number.to_s.sub(/\AS/, '')
                xml.Type 'SO'
                xml.Status status
              end
            end
          end
        end
      end
      private_class_method :save_rq_pick

      def self.coerce(order)
        return order if order.is_a?(Picking)

        if order.is_a?(Shipping)
          new(order.order_number)
        elsif order.is_a?(Hash)
          new(
            order[:order_number] || order['order_number'],
            action: order[:action] || order['action'] || ACTION_FINISH
          )
        else
          new(order)
        end
      end
      private_class_method :coerce
    end
  end
end
