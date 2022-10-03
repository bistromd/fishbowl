# frozen_string_literal: true

module Fishbowl
  module Models
    class Location < Base
      def self.all(format = nil)
        send_request(
          Nokogiri::XML::Builder.new do |xml|
            xml.request do
              xml.LocationListRq
            end
          end, format || FORMAT
        )
      end
    end
  end
end
