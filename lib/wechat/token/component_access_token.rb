# frozen_string_literal: true

require 'wechat/token/access_token_base'

module Wechat
  module Token
    class ComponentAccessToken < AccessTokenBase
      def initialize(client, appid, secret, token_file, ticket_file)
        @appid = appid
        @secret = secret
        @client = client
        @token_file = token_file
        @ticket_file = ticket_file
        @random_generator = Random.new
      end

      def refresh
        component_verify_ticket = ComponentVerifyTicket.new @ticket_file
        ticket = component_verify_ticket.ticket
        data = client.get('component/api_component_token', params: { component_verify_ticket: ticket, component_appid: appid, component_appsecret: secret })
        write_token_to_store(data)
        read_token_from_store
      end
    end
  end
end
