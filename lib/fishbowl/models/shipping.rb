# frozen_string_literal: true

module Fishbowl
  module Models
    # Step 2: ship a picked order via ShipRq.
    class Shipping < Base
      ACTION_SHIP = 'Ship'
      DEFAULT_CARTON_NUM = '1'

      attr_accessor :order_number, :carrier, :tracking_number, :carton_num, :action_type

      def initialize(order_number, carrier, tracking_number, carton_num: DEFAULT_CARTON_NUM,
                     action_type: ACTION_SHIP)
        super
        @order_number = order_number
        @carrier = carrier
        @tracking_number = tracking_number
        @carton_num = carton_num
        @action_type = action_type
      end

      def self.ship(shipments, format = nil)
        Array(shipments).map { |shipment| ship_one(coerce(shipment), format) }
      end

      def self.ship_one(shipment, format = nil)
        send_request(ship_request(shipment), format || FORMAT)
      end

      def self.pick_and_ship(shipments, format = nil)
        shipment_rows = Array(shipments).map { |shipment| coerce(shipment) }
        Picking.pick(shipment_rows, format)
        ship(shipment_rows, format)
      end

      def self.ship_request(shipment)
        Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.ShipRq do
              xml.OrderNumber shipment.order_number.to_s
              xml.Carrier shipment.carrier
              xml.ShipCarton do
                xml.CartonNum shipment.carton_num
                xml.TrackingNum shipment.tracking_number
              end
              xml.ActionType shipment.action_type
            end
          end
        end
      end

      def self.coerce(shipment)
        return shipment if shipment.is_a?(Shipping)

        if shipment.is_a?(Hash)
          new(
            shipment[:order_number] || shipment['order_number'],
            shipment[:carrier] || shipment['carrier'],
            shipment[:tracking_number] || shipment['tracking_number'],
            carton_num: shipment[:carton_num] || shipment['carton_num'] || DEFAULT_CARTON_NUM,
            action_type: shipment[:action_type] || shipment['action_type'] || ACTION_SHIP
          )
        else
          order_number, carrier, tracking_number, carton_num = shipment
          new(
            order_number,
            carrier,
            tracking_number,
            carton_num: carton_num || DEFAULT_CARTON_NUM
          )
        end
      end
      private_class_method :coerce
    end
  end
end
