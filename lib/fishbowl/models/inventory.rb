# frozen_string_literal: true

module Fishbowl
  module Models
    class Inventory < Base
      ALL_QUERY = "SELECT PRODUCT.SKU, Q.QTYONHAND - Q.QTYALLOCATEDSO as AvailableQuantity,
      Q.LOCATIONGROUPID FROM QTYINVENTORY Q
      inner join PRODUCT on Q.partid = PRODUCT.partid
      where (q.locationgroupid = 3 or q.locationgroupid = 5)"
      def self.all
        fishbowl_data = {}
        format_sql(Fishbowl::Connection.query(ALL_QUERY)).each do |data|
          key = data['SKU']
          fishbowl_data[key] = fishbowl_data.fetch(key) { {} }.merge(
            { data['LOCATIONGROUPID'].to_i => data['AvailableQuantity'].to_i }
          )
        end
        fishbowl_data
      end
    end
  end
end
