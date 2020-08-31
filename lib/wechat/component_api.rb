# frozen_string_literal: true

require 'wechat/api'

module Wechat
  class ComponentApi < Api
    def initialize(authorizer_appid, authorizer_refresh_token, component_appid, component_secret, token_file, component_token_file, component_ticket_file, timeout, skip_verify_ssl, jsapi_ticket_file)
      @client = HttpClient.new(Wechat::Api::API_BASE, timeout, skip_verify_ssl)
      @access_token = Token::AuthorizerAccessToken.new(@client, authorizer_appid, authorizer_refresh_token, component_appid, component_secret, token_file, component_token_file, component_ticket_file)
      @jsapi_ticket = Ticket::PublicJsapiTicket.new(@client, @access_token, jsapi_ticket_file)
    end
  end
end
