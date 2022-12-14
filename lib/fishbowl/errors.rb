# frozen_string_literal: true

require 'yaml'
module Fishbowl
  module Errors
    class ConnectionNotEstablished < RuntimeError; end
    class MissingMysqlUrl < ArgumentError; end
    class MissingHost < ArgumentError; end
    class MissingUsername < ArgumentError; end
    class MissingPassword < ArgumentError; end
    class EmptyResponse < RuntimeError; end

    class StatusError < RuntimeError; end
    class RetryStatusError < RuntimeError; end
    RETRY_STATUS_CODES = [1002, 1010, 1131].freeze
    def self.confirm_success_or_raise(code)
      success = 1000
      raise(RetryStatusError, status(code)) if RETRY_STATUS_CODES.include? code.to_i
      raise(StatusError, status(code)) unless code.to_i.eql?(success)
    end

    def self.status(code)
      file = File.expand_path('../status_codes.yml', File.dirname(__FILE__))
      status_codes = YAML.load_file(file)['codes']
      status_codes[code.to_i]['message']
    end
  end
end
