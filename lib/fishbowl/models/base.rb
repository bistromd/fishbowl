# frozen_string_literal: true

require 'csv'
module Fishbowl
  module Models
    class Base
      FORMAT = 'json'
      def initialize(*args)
        puts 'Initialize Object', args if Fishbowl.configuration.debug
      end

      def to_csv
        self.class.const_get(:ATTRIBUTES).map { |attribute| send(attribute) }.to_csv
      end

      def self.send_query_request(sql)
        payload = Nokogiri::XML::Builder.new do |xml|
          xml.request do
            xml.ExecuteQueryRq do
              xml.Query sql
            end
          end
        end
        data = send_request(payload, FORMAT)
        response = data.dig('FbiXml', 'FbiMsgsRs', 'ExecuteQueryRs', 'Rows', 'Row')
        CSV.parse(response.join("\r\n"))
      end

      def self.send_request(payload, format = nil)
        _code, response = Fishbowl::Connection.request(payload, format)
        puts 'Response successful' if Fishbowl.configuration.debug

        response
      end

      def self.attributes
        %w[ID]
      end

      def self.format_sql(result)
        headers = result.fields.map(&:name)
        result.map do |data|
          index = -1
          data.to_h do |item|
            index += 1
            [headers[index], (headers[index] == 'customFields' ? JSON.parse(item) : item)]
          end
        end
      end

      protected

      def parse_attributes
        self.class.attributes.each do |field|
          field = field.to_s

          instance_var = case field
                         when 'ID'
                           'db_id'
                         when /^[A-Z]{3,}$/
                           field.downcase
                         else
                           field.gsub(/ID$/, 'Id').underscore
                         end

          instance_var = "@#{instance_var}"
          value = @xml.children.nil? ? nil : @xml.children.text
          instance_variable_set(instance_var, value)
        end
      end
    end
  end
end
