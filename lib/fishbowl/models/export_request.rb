# frozen_string_literal: true

require 'csv'
module Fishbowl
  module Models
    class ExportRequest < Base
      def self.all(format = nil)
        send_request(
          Nokogiri::XML::Builder.new do |xml|
            xml.request do
              xml.ExportListRq
            end
          end, format || FORMAT
        )
      end
    end
  end
end
