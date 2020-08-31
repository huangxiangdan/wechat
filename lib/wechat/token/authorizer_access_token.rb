# frozen_string_literal: true

require 'wechat/token/access_token_base'

module Wechat
  module Token
    class AuthorizerAccessToken < AccessTokenBase
      attr_reader :component_ticket_file

      def initialize(client, authorizer_appid, authorizer_refresh_token, component_appid, component_secret, token_file, component_token_file, component_ticket_file)
        super.initialize(client, authorizer_appid, authorizer_refresh_token, token_file)
        @authorizer_appid = authorizer_appid
        @component_access_token = ComponentAccessToken.new(client, component_appid, component_secret, component_token_file, component_ticket_file)
        @component_appid = component_appid
        @component_ticket_file = component_ticket_file
        @authorizer_refresh_token = authorizer_refresh_token
      end

      def refresh
        component_access_token = component_access_token.token
        data = client.post("component/api_authorizer_token?component_access_token=#{component_access_token}", params: { component_appid: @component_appid, authorizer_appid: @authorizer_appid, authorizer_refresh_token: @authorizer_refresh_token })
        data['access_token'] = data['authorizer_access_token']
        write_token_to_store(data)
        read_token_from_store
      end
    end
  end
end
