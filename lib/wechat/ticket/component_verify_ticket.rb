# frozen_string_literal: true

require 'digest/sha1'
require 'securerandom'

module Wechat
  module Ticket
    class ComponentVerifyTicket
      attr_reader :component_ticket_file, :access_ticket, :ticket_life_in_seconds, :got_ticket_at, :component_appid

      def initialize(component_ticket_file, component_appid)
        @component_ticket_file = component_ticket_file
        @component_appid = component_appid
      end

      def ticket
        # Possible two worker running, one worker refresh ticket, other unaware, so must read every time
        read_ticket_from_store
        access_ticket
      end

      def write_ticket_to_store(ticket_hash)
        ticket_hash['got_ticket_at'] = Time.now.to_i
        write_ticket(ticket_hash)
      end

      protected

      def read_ticket_from_store
        td = read_ticket
        @got_ticket_at = td.fetch('got_ticket_at').to_i
        @access_ticket = td.fetch('ticket') # return access_ticket same time
      rescue JSON::ParserError, Errno::ENOENT, KeyError, TypeError
        raise "component_verify_ticket is missing"
      end

      def read_ticket
        JSON.parse(File.read(component_ticket_file))
      end

      def write_ticket(ticket_hash)
        File.write(component_ticket_file, ticket_hash.to_json)
      end

      def remain_life_seconds
        ticket_life_in_seconds - (Time.now.to_i - got_ticket_at)
      end
    end
  end
end
