# frozen_string_literal: true

module Wechat
  module ApiLoader
    def self.with(options)
      account = options[:account] || :default
      c = ApiLoader.config(account)

      token_file = options[:token_file] || c.access_token.presence || '/var/tmp/wechat_access_token'
      js_token_file = options[:js_token_file] || c.jsapi_ticket.presence || '/var/tmp/wechat_jsapi_ticket'
      component_token_file = options[:component_token] || c.component_token.presence || '/var/tmp/component_token'
      component_ticket_file = options[:component_ticket] || c.component_ticket.presence || '/var/tmp/component_ticket'
      type = options[:type] || c.type
      if c.appid && c.secret && token_file.present?
        wx_class = type == 'mp' ? Wechat::MpApi : Wechat::Api
        wx_class.new(c.appid, c.secret, token_file, c.timeout, c.skip_verify_ssl, js_token_file)        
      elsif c.corpid && c.corpsecret && token_file.present?
        Wechat::CorpApi.new(c.corpid, c.corpsecret, token_file, c.agentid, c.timeout, c.skip_verify_ssl, js_token_file)
      elsif c.component_appid && c.component_secret && component_token_file.present?
        Wechat::ComponentApi.new(c.authorizer_appid, c.authorizer_refresh_token, c.component_appid, c.component_secret, token_file, component_token_file, \
          component_ticket_file, c.timeout, c.skip_verify_ssl, js_token_file)
      else
        raise 'Need create ~/.wechat.yml with wechat appid and secret or running at rails root folder so wechat can read config/wechat.yml'
      end
    end

    @configs = nil

    def self.config(account = :default)
      account = :default if account.nil?
      @configs ||= loading_config!
      @configs[account.to_sym] || raise("Wechat configuration for #{account} is missing.")
    end

    def self.reload_config!
      @configs = loading_config!
    end

    private_class_method def self.loading_config!
      configs = config_from_file || config_from_environment
      configs.merge!(config_from_db)

      configs.symbolize_keys!
      configs.each do |key, cfg|
        raise "wrong wechat configuration format for #{key}" unless cfg.is_a?(Hash)

        cfg.symbolize_keys!
      end

      if defined?(::Rails)
        configs.each do |_, cfg|
          cfg[:access_token] ||= Rails.root.try(:join, 'tmp/access_token').try(:to_path)
          cfg[:jsapi_ticket] ||= Rails.root.try(:join, 'tmp/jsapi_ticket').try(:to_path)
          cfg[:component_token] ||= Rails.root.try(:join, 'tmp/component_token').try(:to_path)
          cfg[:component_ticket] ||= Rails.root.try(:join, 'tmp/component_ticket').try(:to_path)
        end
      end

      configs.each do |_, cfg|
        cfg[:timeout] ||= 20
        cfg[:have_session_class] = class_exists?('WechatSession')
        cfg[:oauth2_cookie_duration] ||= 1.hour
      end

      # create config object using raw config data
      cfg_objs = {}
      configs.each do |account, cfg|
        cfg_objs[account] = OpenStruct.new(cfg)
      end
      cfg_objs
    end

    private_class_method def self.config_from_db
      return {} unless class_exists?('WechatConfig')

      environment = defined?(::Rails) ? Rails.env.to_s : ENV['RAILS_ENV'] || 'development'
      WechatConfig.get_all_configs(environment)
    end

    private_class_method def self.config_from_file
      if defined?(::Rails)
        config_file = ENV['WECHAT_CONF_FILE'] || Rails.root.join('config', 'wechat.yml')
        resolve_config_file(config_file, Rails.env.to_s)
      else
        rails_config_file = ENV['WECHAT_CONF_FILE'] || File.join(Dir.getwd, 'config', 'wechat.yml')
        application_config_file = File.join(Dir.getwd, 'config', 'application.yml')
        home_config_file = File.join(Dir.home, '.wechat.yml')
        if File.exist?(rails_config_file)
          rails_env = ENV['RAILS_ENV'] || 'development'
          if File.exist?(application_config_file) && !defined?(::Figaro)
            require 'figaro'
            Figaro::Application.new(path: application_config_file, environment: rails_env).load
          end
          config = resolve_config_file(rails_config_file, rails_env)
          if config.present? && (default = config[:default]) && (default['appid'] || default['corpid'] || default['component_appid'])
            puts "Using rails project #{ENV['WECHAT_CONF_FILE'] || 'config/wechat.yml'} #{rails_env} setting..."
            return config
          end
        end
        return resolve_config_file(home_config_file, nil) if File.exist?(home_config_file)
      end
    end

    private_class_method def self.resolve_config_file(config_file, env)
      return unless File.exist?(config_file)

      begin
        # rubocop:disable Security/YAMLLoad
        raw_data = YAML.load(ERB.new(File.read(config_file)).result)
        # rubocop:enable Security/YAMLLoad
      rescue NameError
        puts "WARNING: If using 'Rails.application.credentials.wechat_secret!' in wechat.yml, you need run in 'rails c' and access via 'Wechat.api' or gem 'figaro' instead."
      end
      configs = {}
      if env
        # Process multiple accounts when env is given
        raw_data.each do |key, value|
          if key == env
            configs[:default] = value
          else
            m = /(.*?)_#{env}$/.match(key)
            configs[m[1].to_sym] = value if m
          end
        end
      else
        # Treat is as one account when env is omitted
        configs[:default] = raw_data
      end
      configs
    end

    private_class_method def self.config_from_environment
      value = { appid: ENV['WECHAT_APPID'],
                secret: ENV['WECHAT_SECRET'],
                corpid: ENV['WECHAT_CORPID'],
                corpsecret: ENV['WECHAT_CORPSECRET'],
                agentid: ENV['WECHAT_AGENTID'],
                component_appid: ENV['component_appid'],
                component_secret: ENV['component_secret'],
                authorizer_appid: ENV['authorizer_appid'],
                authorizer_refresh_token: ENV['authorizer_refresh_token'],
                component_token: ENV['component_token'],
                component_ticket: ENV['component_ticket'],
                token: ENV['WECHAT_TOKEN'],
                access_token: ENV['WECHAT_ACCESS_TOKEN'],
                encrypt_mode: ENV['WECHAT_ENCRYPT_MODE'],
                timeout: ENV['WECHAT_TIMEOUT'],
                skip_verify_ssl: ENV['WECHAT_SKIP_VERIFY_SSL'],
                encoding_aes_key: ENV['WECHAT_ENCODING_AES_KEY'],
                jsapi_ticket: ENV['WECHAT_JSAPI_TICKET'],
                trusted_domain_fullname: ENV['WECHAT_TRUSTED_DOMAIN_FULLNAME'] }
      { default: value }
    end

    private_class_method def self.class_exists?(class_name)
      klass = Module.const_get(class_name)
      klass.is_a?(Class)
    rescue NameError
      false
    end
  end
end
