class Webhooks::WhatsappProvidersController < ActionController::API
  wrap_parameters false
  def create
    channel = find_channel
    return head :not_found unless channel&.inbox && channel.account.active?
    return head :payload_too_large if request.raw_post.bytesize > 2.megabytes
    return head :unauthorized unless authentic?(channel)

    # Strip authentication before entering Sidekiq, its retries and logs.
    fingerprint = Digest::SHA256.hexdigest(channel.provider_config.to_json)
    encrypted_payload = ActiveRecord::Encryption.encryptor.encrypt(sanitized_payload.to_json)
    Webhooks::WhatsappProviderEventsJob.perform_later(channel.id, encrypted_payload, fingerprint)
    head :ok
  end

  private

  def sanitized_payload
    # Pairing data is redacted in HTTP logs but retained inside the encrypted job envelope.
    filters = Rails.application.config.filter_parameters - [:qr, :paircode]
    ActiveSupport::ParameterFilter.new(filters + [:webhookVerifyToken])
                                  .filter(request.request_parameters.except('token', 'webhookVerifyToken', 'webhook_token'))
  end

  def find_channel
    definition = Whatsapp::ProviderRegistry::DEFINITIONS[params[:provider]]
    return unless definition&.session

    Channel::Whatsapp.find_by(id: params[:channel_id], provider: definition.id)
  end

  def authentic?(channel)
    config = channel.provider_config
    return false unless matches?(params[:webhook_token], config['webhook_verify_token'])
    return matches?(params[:token], config['token']) if channel.provider == 'uazapi'
    return matches?(params[:webhookVerifyToken], config['webhook_verify_token']) if channel.provider == 'baileys'

    # Z-API has no documented signature: use the unguessable per-inbox callback token
    # plus its instance identifier. HTTPS is mandatory at the public endpoint.
    params[:instanceId].to_s == config['instance_id'].to_s && config['instance_id'].present?
  end

  def matches?(given, expected)
    given.present? && expected.present? && ActiveSupport::SecurityUtils.secure_compare(given.to_s, expected.to_s)
  end
end
