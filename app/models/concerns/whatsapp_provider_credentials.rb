module WhatsappProviderCredentials
  extend ActiveSupport::Concern
  SECRET_KEYS = %w[api_key token client_token webhook_verify_token app_secret verification_pin].freeze
  PUBLIC_KEYS = %w[phone_number_id business_account_id source instance_id calling_enabled inbound_calls_enabled].freeze

  included do
    serialize :provider_credentials, coder: JSON, type: Hash
    encrypts :provider_credentials
    self.filter_attributes += [:provider_config]
  end

  # Retain the existing service contract while keeping secrets out of the JSONB column.
  def provider_config
    values = (super || {}).reject { |key, value| SECRET_KEYS.include?(key) && value.blank? }
    (provider_credentials || {}).except('qr_data_url').merge(values)
  end

  def public_provider_config
    provider_config.slice(*PUBLIC_KEYS)
  end

  private

  def protect_provider_credentials
    values = self[:provider_config] || {}
    # Blank inputs mean keep, including clients that omit credentials when editing.
    old_values = (provider_config_in_database || {}).slice(*SECRET_KEYS)
    supplied = values.slice(*SECRET_KEYS).reject { |_key, value| value.blank? }
    secrets = old_values.merge(provider_credentials || {}).merge(supplied)
    return if secrets.empty?

    unless Chatwoot.encryption_configured?
      errors.add(:base, I18n.t('whatsapp_providers.encryption_required'))
      throw(:abort)
    end
    self.provider_credentials = secrets
    self[:provider_config] = values.except(*SECRET_KEYS)
  end
end
