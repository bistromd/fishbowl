# frozen_string_literal: true

require 'nokogiri'
require 'nori'
require 'digest/md5'
require 'mysql'

module Fishbowl
  # Connection class for Fishbowl
  class Connection
    include Singleton
    DEFAULT_PORT = 28_192
    SUCCESS = '1000'
    DEFAULT_FORMAT = 'xml'

    class << self
      attr_reader :host, :port, :username, :password
    end

    def self.query(sql)
      mysql_client.query(sql)
    rescue Mysql::ClientError::ServerGoneError
      @mysql_client = nil
      retry
    end

    def self.prepare(sql, values)
      stmt = mysql_client.prepare(sql)
      stmt.execute(*values)
    rescue Mysql::ClientError::ServerGoneError
      @mysql_client = nil
      retry
    end

    def self.mysql_client
      raise Fishbowl::Errors::MissingMysqlUrl if (mysql_url = Fishbowl.configuration.mysql_url).nil?

      @mysql_client ||= Mysql.connect(mysql_url)
    end

    def self.connect
      return instance if @connection

      run_validations
      host = Fishbowl.configuration.host
      port = Fishbowl.configuration.port.nil? ? DEFAULT_PORT : Fishbowl.configuration.port
      login(host, port)

      instance
    end

    def self.request(payload, format = DEFAULT_FORMAT)
      puts 'opening connection...' if Fishbowl.configuration.debug
      write(payload)
      puts 'waiting for response...' if Fishbowl.configuration.debug
      response(format || DEFAULT_FORMAT)
    end

    def self.close
      @connection.close
      @connection = nil
    end

    def self.xml_formatter(data)
      response = Nokogiri::XML.parse(data)
      status_code = response.xpath('/FbiXml/FbiMsgsRs').attr('statusCode').value
      @ticket = response.xpath('/FbiXml/Ticket/Key').text
      [status_code, response]
    end

    def self.json_formatter(data)
      response = Nori.new(parser: :nokogiri).parse(data)
      status_code = response.dig('FbiXml', 'FbiMsgsRs', '@statusCode')
      @ticket = response.dig('FbiXml', 'Ticket', 'Key')
      [status_code, response]
    end

    def self.build_payload(payload)
      new_req = Nokogiri::XML::Builder.new do |xml|
        xml.FbiXml do
          if @ticket.nil?
            xml.Ticket
          else
            xml.Ticket do
              xml.Key @ticket
            end
          end

          xml.FbiMsgsRq do
            if payload.respond_to?(:to_xml)
              xml << payload.doc.xpath('request/*').to_xml
            else
              xml.send(payload.to_s)
            end
          end
        end
      end
      Nokogiri::XML(new_req.to_xml).root
    end

    def self.run_validations
      raise Fishbowl::Errors::MissingHost if Fishbowl.configuration.host.nil?
      raise Fishbowl::Errors::MissingUsername if Fishbowl.configuration.host.nil?
      raise Fishbowl::Errors::MissingPassword if Fishbowl.configuration.host.nil?
    end

    def self.login(host, port)
      raise Fishbowl::Errors::ConnectionNotEstablished if (@connection = TCPSocket.new(host, port)).nil?

      code, _payload = request(login_payload)
      Fishbowl::Errors.confirm_success_or_raise(code)

      raise 'Login failed' unless code.eql? SUCCESS
    end

    def self.login_payload
      Nokogiri::XML::Builder.new do |xml|
        xml.request do
          xml.LoginRq do
            xml.IAID          Fishbowl.configuration.app_id
            xml.IAName        Fishbowl.configuration.app_name
            xml.IADescription Fishbowl.configuration.app_description
            xml.UserName      Fishbowl.configuration.username
            xml.UserPassword  encoded_password
          end
        end
      end
    end

    def self.encoded_password
      password = Fishbowl.configuration.password
      Fishbowl.configuration.encode_password ? Digest::MD5.base64digest(password) : password
    end

    def self.write(payload)
      body = build_payload(payload).to_xml
      puts body if Fishbowl.configuration.debug
      size = [body.size].pack('L>')
      @connection.write(size)
      @connection.write(body)
    end

    def self.response(format)
      puts 'reading response' if Fishbowl.configuration.debug
      length = @connection.read(4).unpack('L>').join.to_i
      data = @connection.read(length)
      puts data if Fishbowl.configuration.debug
      if format.eql? 'xml'
        xml_formatter(data)
      else
        json_formatter(data)
      end
    end
  end
end
