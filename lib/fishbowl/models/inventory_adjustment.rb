# frozen_string_literal: true

require 'csv'
require 'date'

module Fishbowl
  module Models
    # Add on-hand inventory via ImportAddInventory.
    class InventoryAdjustment < Base
      HEADERS = [
        'PartNumber', 'PartDescription', 'Location', 'Qty', 'UOM', 'Cost', 'QbClass', 'Date', 'Note',
        'Tracking-Lot Number', 'Tracking-Expiration Date', 'Tracking-Revision Level'
      ].freeze
      PREFERRED_LOCATIONS = %w[Stock].freeze

      attr_accessor :part_number, :part_description, :location, :quantity, :uom, :cost, :qb_class, :date, :note,
                    :lot_number, :expiration_date, :revision_level

      def initialize(part_number, quantity, location:, uom: 'ea', cost: 0, date: Date.today.strftime('%Y-%m-%d'),
                     note: '', part_description: '', qb_class: '', lot_number: '', expiration_date: '',
                     revision_level: '')
        super
        @part_number = part_number.to_s
        @part_description = part_description.to_s
        @location = location.to_s
        @quantity = quantity
        @uom = uom.to_s
        @cost = cost
        @qb_class = qb_class.to_s
        @date = date
        @note = note.to_s
        @lot_number = lot_number.to_s
        @expiration_date = expiration_date.to_s
        @revision_level = revision_level.to_s
      end

      def to_csv
        self.class.quoted_csv_row([
          part_number,
          part_description,
          location,
          quantity,
          uom,
          format('%.2f', cost.to_f),
          qb_class,
          date,
          note,
          lot_number,
          expiration_date,
          revision_level
        ])
      end

      def self.quoted_csv_row(values)
        CSV.generate_line(values, force_quotes: true).chomp
      end

      def self.header_row
        HEADERS.join(',')
      end

      def self.add(adjustments, format = nil)
        rows = [header_row] + Array(adjustments).map { |adjustment| coerce(adjustment) }
        ImportRequest.create(ImportRequest::ADD_INVENTORY, rows, format)
      end

      def self.add_for_order(order_number, location: nil, cost: nil, note: nil, date: nil, format: nil)
        adjustments = build_adjustments_for_order(order_number, location: location, cost: cost, note: note, date: date)
        raise Fishbowl::Errors::StatusError, "No line items found on order #{order_number}" if adjustments.empty?

        add(adjustments, format)
      end

      def self.preview_for_order(order_number, **options)
        build_adjustments_for_order(order_number, **options)
      end

      def self.build_adjustments_for_order(order_number, location: nil, cost: nil, note: nil, date: nil)
        items = line_items_from_order(order_number)
        return [] if items.empty?

        loc = location || default_location_for_order(order_number)
        default_cost = cost.nil? ? ENV.fetch('FISHBOWL_INVENTORY_DEFAULT_COST', '0').to_f : cost.to_f
        note ||= "Add inventory for SO #{order_number}"
        date ||= Date.today.strftime('%Y-%m-%d')
        tracking = part_metadata_for_parts(items.map { |item| item[:part_number] })

        items.each_with_index.filter_map do |item, index|
          metadata = tracking[item[:part_number]] || {}
          next unless metadata.fetch(:inventory, false)

          item_cost = item[:cost].to_f
          item_cost = default_cost if item_cost <= 0
          tracked = metadata[:tracked]

          new(
            item[:part_number],
            item[:quantity],
            location: loc,
            uom: item[:uom],
            cost: item_cost,
            date: date,
            note: note,
            part_description: item[:description],
            lot_number: tracked ? lot_number_for(item[:part_number], order_number, index + 1) : '',
            expiration_date: tracked ? default_expiration_date : '',
            revision_level: ''
          )
        end
      end

      def self.skipped_items_for_order(order_number)
        items = line_items_from_order(order_number)
        metadata = part_metadata_for_parts(items.map { |item| item[:part_number] })
        items.filter_map do |item|
          next if metadata.fetch(item[:part_number], {})[:inventory]

          {
            part_number: item[:part_number],
            quantity: item[:quantity],
            reason: 'non-inventory part type'
          }
        end
      end

      def self.line_items_from_order(order_number)
        so = SalesOrder.find(order_number, 'json')
               .dig('FbiXml', 'FbiMsgsRs', 'LoadSORs', 'SalesOrder')
        raise Fishbowl::Errors::StatusError, "Sales order not found: #{order_number}" unless so

        items = so.dig('Items', 'SalesOrderItem')
        return [] if items.nil?

        items = [items] unless items.is_a?(Array)
        items.filter_map do |item|
          part_number = item['ProductNumber']
          next if part_number.nil? || part_number.to_s.empty?

          {
            part_number: part_number,
            quantity: item['Quantity'],
            uom: item['UOMCode'] || item['UOM'] || 'ea',
            cost: item['ProductPrice'] || item['TotalPrice'] || 0,
            description: item['Description']
          }
        end
      end

      def self.default_location_for_order(order_number)
        env_location = ENV['FISHBOWL_INVENTORY_LOCATION']&.strip
        return env_location if env_location&.length&.positive?

        so = SalesOrder.find(order_number, 'json')
               .dig('FbiXml', 'FbiMsgsRs', 'LoadSORs', 'SalesOrder')
        group = so&.fetch('LocationGroup', nil)
        raise Fishbowl::Errors::StatusError, "Cannot resolve location for order #{order_number}" if group.nil?

        rows = query_rows(
          'SELECT location.name FROM location ' \
          'JOIN locationgroup ON location.locationGroupId = locationgroup.id ' \
          "WHERE locationgroup.name = '#{sanitize_sql(group)}' " \
          'AND location.activeFlag = 1 ' \
          'ORDER BY location.name'
        )
        names = rows.drop(1).map { |row| parse_query_value(row) }.compact
        preferred = PREFERRED_LOCATIONS.find { |name| names.include?(name) }
        return preferred if preferred
        return names.first if names.any?

        "#{group}-Stock"
      end

      def self.part_metadata_for_parts(part_numbers)
        numbers = part_numbers.uniq
        return {} if numbers.empty?

        quoted = numbers.map { |part_number| "'#{sanitize_sql(part_number)}'" }.join(',')
        rows = query_rows(
          'SELECT product.num, part.trackingFlag, part.typeId ' \
          'FROM product JOIN part ON part.id = product.partId ' \
          "WHERE product.num IN (#{quoted})"
        )

        rows.drop(1).each_with_object({}) do |row, metadata|
          values = parse_query_row(row)
          next if values.length < 3

          metadata[values[0]] = {
            tracked: values[1] == 'true',
            inventory: values[2].to_i == 10
          }
        end
      end

      def self.lot_number_for(part_number, order_number, line_number)
        prefix = ENV.fetch('FISHBOWL_INVENTORY_LOT_PREFIX', 'API')
        "#{prefix}-#{order_number}-#{line_number}-#{part_number}".gsub(/[^A-Za-z0-9._-]/, '-')[0, 50]
      end
      private_class_method :lot_number_for

      def self.default_expiration_date
        days = ENV.fetch('FISHBOWL_INVENTORY_EXPIRATION_DAYS', '365').to_i
        (Date.today + days).strftime('%m/%d/%Y')
      end
      private_class_method :default_expiration_date

      def self.default_revision_level
        ENV.fetch('FISHBOWL_INVENTORY_REVISION_LEVEL', 'A')
      end
      private_class_method :default_revision_level

      def self.query_rows(sql)
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.ExecuteQueryRq do
              xml.Query sql
            end
          end
        end
        response = send_request(payload, FORMAT)
        rows = response.dig('FbiXml', 'FbiMsgsRs', 'ExecuteQueryRs', 'Rows', 'Row')
        return [] if rows.nil?

        rows.is_a?(Array) ? rows : [rows]
      end

      def self.parse_query_value(row)
        parse_query_row(row).first
      end
      private_class_method :parse_query_value

      def self.parse_query_row(row)
        CSV.parse_line(row.to_s) || []
      rescue CSV::MalformedCSVError
        row.to_s.split(',')
      end
      private_class_method :parse_query_row

      def self.sanitize_sql(value)
        value.to_s.gsub("'", "''")
      end
      private_class_method :sanitize_sql

      def self.coerce(adjustment)
        return adjustment if adjustment.is_a?(InventoryAdjustment)

        if adjustment.is_a?(Hash)
          new(
            adjustment[:part_number] || adjustment['part_number'],
            adjustment[:quantity] || adjustment['quantity'],
            location: adjustment[:location] || adjustment['location'],
            uom: adjustment[:uom] || adjustment['uom'] || 'ea',
            cost: adjustment[:cost] || adjustment['cost'] || 0,
            date: adjustment[:date] || adjustment['date'] || Date.today.strftime('%Y-%m-%d'),
            note: adjustment[:note] || adjustment['note'] || '',
            part_description: adjustment[:part_description] || adjustment['part_description'] || '',
            qb_class: adjustment[:qb_class] || adjustment['qb_class'] || '',
            lot_number: adjustment[:lot_number] || adjustment['lot_number'] || '',
            expiration_date: adjustment[:expiration_date] || adjustment['expiration_date'] || '',
            revision_level: adjustment[:revision_level] || adjustment['revision_level'] || ''
          )
        else
          part_number, quantity, location, uom, cost, date, note = adjustment
          new(part_number, quantity, location: location, uom: uom || 'ea', cost: cost || 0, date: date, note: note)
        end
      end
      private_class_method :coerce
    end
  end
end
