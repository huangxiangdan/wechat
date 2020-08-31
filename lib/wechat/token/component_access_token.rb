# frozen_string_literal: true

require 'wechat/token/access_token_base'
require 'wechat/ticket/component_verify_ticket'

module Wechat
  module Token
    class ComponentAccessToken < AccessTokenBase
      def initialize(client, appid, secret, token_file, ticket_file)
        super(client, appid, secret, token_file)
        @ticket_file = ticket_file
      end

      def refresh
        component_verify_ticket = Ticket::ComponentVerifyTicket.new @ticket_file, appid
        ticket = component_verify_ticket.ticket
        data = client.post('component/api_component_token', { component_verify_ticket: ticket, component_appid: appid, component_appsecret: secret }.to_json)
        write_token_to_store(data)
        read_token_from_store
      end

      def write_token_to_store(token_hash)
        raise InvalidCredentialError unless token_hash.is_a?(Hash) && token_hash['component_access_token']
        token_hash['access_token'] = token_hash.delete 'component_access_token'
        super
      end
    end
  end
end
