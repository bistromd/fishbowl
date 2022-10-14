# frozen_string_literal: true

module Fishbowl
  class Configuration
    attr_accessor :username, :password, :host, :port, :app_id, :app_name, :timeout,
                  :app_description, :debug, :encode_password, :mysql_url
  end
end
