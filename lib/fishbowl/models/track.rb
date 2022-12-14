# frozen_string_literal: true

module Fishbowl
  module Models
    class Track < Base
      ALL_QUERY = 'SELECT so.num, shipcarton.trackingnum FROM shipcarton
                   INNER JOIN so ON shipcarton.orderId=so.id WHERE shipcarton.dateCreated >= ?'
      def self.all(date_created = Date.today.prev_day.to_time)
        format_sql(Fishbowl::Connection.prepare(ALL_QUERY, [date_created])).to_h do |data|
          [data['num'], data['trackingnum']]
        end
      end
    end
  end
end
