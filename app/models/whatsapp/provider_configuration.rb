# InstallationConfig is an unencrypted, broadly serialized key/value store. Secrets
# belong here instead, with a unique row and schema for each supported provider.
class Whatsapp::ProviderConfiguration < ApplicationRecord
  self.table_name = 'whatsapp_provider_configurations'
  serialize :credentials, coder: JSON, type: Hash
  encrypts :credentials

  SETTINGS = %w[base_url client_name allow_private_network].freeze
  SECRETS = %w[api_key].freeze
  LEGACY_ENV = { 'base_url' => 'BAILEYS_PROVIDER_DEFAULT_URL', 'api_key' => 'BAILEYS_PROVIDER_DEFAULT_API_KEY',
                 'client_name' => 'BAILEYS_PROVIDER_DEFAULT_CLIENT_NAME' }.freeze

  validates :provider, inclusion: { in: Whatsapp::ProviderRegistry::DEFINITIONS.keys }, uniqueness: true
  validate :encryption_available
  validate :valid_configuration
  validate :baileys_credentials

  def definition
    Whatsapp::ProviderRegistry.fetch(provider)
  end

  def effective_settings
    defaults = provider == 'baileys' ? LEGACY_ENV.transform_values { |key| ENV[key].presence }.compact : {}
    defaults.merge(settings).merge(credentials || {})
  end

  def assign_configuration(attributes)
    self.enabled = attributes.fetch('enabled', enabled)
    self.settings = settings.merge(attributes.slice(*SETTINGS))
    self.credentials = (credentials || {}).merge(attributes.slice(*SECRETS).reject { |_key, value| value.blank? })
  end

  def serializable_hash(options = nil)
    super.except('credentials')
  end

  private

  def encryption_available
    errors.add(:base, I18n.t('whatsapp_providers.encryption_required')) unless Chatwoot.encryption_configured?
  end

  def valid_configuration
    return unless Whatsapp::ProviderRegistry::DEFINITIONS.key?(provider)
    return unless enabled?
    return unless definition.session

    values = effective_settings
    errors.add(:settings, :invalid) unless provider == 'zapi' || valid_endpoint?(values['base_url'])
  end

  def baileys_credentials
    return unless provider == 'baileys' && enabled?

    errors.add(:credentials, :blank) if effective_settings['api_key'].blank?
  end

  def valid_endpoint?(value)
    uri = URI.parse(value.to_s)
    return false unless uri.is_a?(URI::HTTP) && uri.host.present?
    return false if [uri.userinfo, uri.query, uri.fragment].any?

    uri.scheme == 'https' || settings['allow_private_network'] == true
  rescue URI::InvalidURIError
    false
  end
end
