# frozen_string_literal: true

require 'socket'
require 'base64'
require 'nokogiri'
require 'fishbowl/version'
require 'fishbowl/errors'
require 'fishbowl/connection'
require 'fishbowl/configuration'
require 'fishbowl/models'

module Fishbowl
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
end
