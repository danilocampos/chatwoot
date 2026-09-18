# HTTP session adapters implement this same channel contract as the official services.
class Whatsapp::Providers::SessionService < Whatsapp::Providers::BaseService
  class Error < StandardError; end
  class OutcomeUnknown < Error; end

  def configuration
    @configuration ||= Whatsapp::ProviderConfiguration.find_or_initialize_by(provider: whatsapp_channel.provider)
  end

  def config
    configuration.effective_settings.merge(whatsapp_channel.provider_config)
  end

  def validate_provider_config?
    Whatsapp::ProviderRegistry.fetch(whatsapp_channel.provider).fields.all? { |field| config[field].present? }
  end

  def sync_templates; end

  def send_template(*)
    raise Error, I18n.t('whatsapp_providers.unsupported')
  end

  def callback_url
    Rails.application.routes.url_helpers.whatsapp_provider_webhook_url(
      provider: whatsapp_channel.provider, channel_id: whatsapp_channel.id,
      webhook_token: whatsapp_channel.provider_config.fetch('webhook_verify_token'), host: ENV.fetch('FRONTEND_URL')
    )
  end

  def test_connection
    request(:get, status_path, timeout: 5)
    true
  end

  def send_message(phone, message)
    raise Error, I18n.t('whatsapp_providers.unsupported') if message.attachments.any? { |attachment| !attachment.with_attached_file? }

    path, body = outgoing_payload(phone.delete('+'), message)
    result = request(:post, path, body: body, timeout: 60)
    id = outgoing_id(result)
    raise OutcomeUnknown, I18n.t('whatsapp_providers.outcome_unknown') if id.blank?

    id
  end

  def media_file(payload, &)
    url, headers = media_location(payload)
    if configuration.settings['allow_private_network'] == true && URI(url).host == URI(configuration.effective_settings.fetch('base_url')).host
      file = Down.download(url, headers: headers, max_size: 40.megabytes, open_timeout: 5, read_timeout: 20, max_redirects: 0)
      return yield SafeFetch::Result.new(tempfile: file, filename: file.original_filename, content_type: file.content_type)
    end
    # A yielded tempfile is closed by SafeFetch, so the attachment is persisted inside
    # the block. Never send API headers to a provider-supplied third-party URL.
    SafeFetch.fetch(url, headers: headers, sensitive_headers: headers.keys, max_bytes: 40.megabytes,
                         validate_content_type: false, &)
  rescue SafeFetch::Error, Down::Error, URI::InvalidURIError, KeyError
    raise Error, I18n.t('whatsapp_providers.media_failed'), cause: nil
  ensure
    file&.close!
  end

  def request(method, path, body: nil, timeout: 20)
    base = configuration.effective_settings.fetch('base_url')
    headers = api_headers.merge('Content-Type' => 'application/json')
    response = transport(method, "#{base.chomp('/')}#{path}", headers, body, timeout)
    raise Error, I18n.t('whatsapp_providers.connection_failed') unless response.code.to_i.between?(200, 299)

    result = JSON.parse(response.body)
    raise Error, I18n.t('whatsapp_providers.connection_failed') unless result.is_a?(Hash)

    result
  rescue Error
    raise
  rescue StandardError
    # No endpoint, token, body or raw exception reaches a job retry/log/API response.
    raise OutcomeUnknown, I18n.t('whatsapp_providers.outcome_unknown'), cause: nil if method == :post && path.include?('send')

    raise Error, I18n.t('whatsapp_providers.connection_failed'), cause: nil
  end

  def attachment_url(attachment)
    attachment.download_url
  end

  def reply_id(message)
    message.content_attributes['in_reply_to_external_id']
  end

  def session_state(values)
    state = values.slice('connection').merge('activated' => whatsapp_channel.provider_connection['activated'])
    credentials = whatsapp_channel.provider_credentials.merge('qr_data_url' => values['qr_data_url'])
    whatsapp_channel.update!(provider_connection: state, provider_credentials: credentials)
  end

  private

  def transport(method, url, headers, body, timeout)
    if configuration.settings['allow_private_network'] == true
      return HTTParty.public_send(method, url, headers: headers, body: body&.to_json,
                                               timeout: timeout, open_timeout: 5, no_follow: true, max_retries: 0)
    end

    options = { open_timeout: 5, read_timeout: timeout, write_timeout: timeout, max_retries: 0 }
    SsrfFilter.public_send(method, url, headers: headers, body: body&.to_json,
                                        max_redirects: 0, sensitive_headers: headers.keys, http_options: options)
  end
end
