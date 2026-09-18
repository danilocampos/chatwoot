# Code is the authority on supported transports; database rows only configure them.
module Whatsapp::ProviderRegistry
  Definition = Data.define(:id, :name, :service, :session, :default_enabled, :fields, :capabilities)
  DEFINITIONS = [
    Definition.new(id: 'whatsapp_cloud', name: 'Meta WhatsApp', service: 'Whatsapp::Providers::WhatsappCloudService',
                   session: false, default_enabled: true, fields: [], capabilities: %w[text media templates statuses]),
    Definition.new(id: 'default', name: '360dialog', service: 'Whatsapp::Providers::Whatsapp360DialogService',
                   session: false, default_enabled: true, fields: [], capabilities: %w[text media templates statuses]),
    Definition.new(id: 'twilio', name: 'Twilio WhatsApp', service: nil,
                   session: false, default_enabled: true, fields: [], capabilities: %w[text media templates statuses]),
    Definition.new(id: 'baileys', name: 'Baileys', service: 'Whatsapp::Providers::BaileysService',
                   session: true, default_enabled: false, fields: [], capabilities: %w[text media statuses replies qr]),
    Definition.new(id: 'zapi', name: 'Z-API', service: 'Whatsapp::Providers::ZapiService',
                   session: true, default_enabled: false, fields: %w[instance_id token client_token],
                   capabilities: %w[text media statuses replies qr]),
    Definition.new(id: 'uazapi', name: 'Uazapi', service: 'Whatsapp::Providers::UazapiService',
                   session: true, default_enabled: false, fields: %w[token], capabilities: %w[text media statuses replies qr])
  ].index_by(&:id).freeze

  def self.fetch(id)
    DEFINITIONS.fetch(id.to_s)
  end

  def self.available?(id, account, configurations: nil)
    definition = DEFINITIONS[id.to_s]
    return false unless definition && account

    config = configurations ? configurations[id.to_s] : Whatsapp::ProviderConfiguration.find_by(provider: id)
    globally_enabled = config ? config.enabled? : definition.default_enabled
    grants = account.settings.fetch('whatsapp_providers', {})
    globally_enabled && grants.fetch(id.to_s, definition.default_enabled) == true
  end

  def self.for_account(account)
    configs = Whatsapp::ProviderConfiguration.all.index_by(&:provider)
    DEFINITIONS.values.select { |definition| available?(definition.id, account, configurations: configs) }
  end
end
