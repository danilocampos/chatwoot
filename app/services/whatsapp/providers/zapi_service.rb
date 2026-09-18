class Whatsapp::Providers::ZapiService < Whatsapp::Providers::SessionService
  def configuration
    super.tap { |value| value.settings = value.settings.merge('base_url' => 'https://api.z-api.io', 'allow_private_network' => false) }
  end

  def api_headers = { 'Client-Token' => config.fetch('client_token') }
  def status_path = "#{instance_path}/status"

  def connect
    request(:put, "#{instance_path}/update-every-webhooks", body: { value: callback_url, notifySentByMe: true })
    qr = request(:get, "#{instance_path}/qr-code/image")
    session_state('connection' => qr['connected'] ? 'open' : 'connecting', 'qr_data_url' => qr['value'])
  end

  def outgoing_payload(phone, message)
    body = { phone: phone, messageId: reply_id(message) }.compact
    attachment = message.attachments.first
    return ["#{instance_path}/send-text", body.merge(message: message.outgoing_content)] unless attachment

    type = { 'file' => 'document' }.fetch(attachment.file_type, attachment.file_type)
    suffix = type == 'document' ? "/#{File.extname(attachment.file.filename.to_s).delete('.').presence || 'bin'}" : ''
    ["#{instance_path}/send-#{type}#{suffix}", body.merge(type => attachment_url(attachment),
                                                          :caption => message.outgoing_content, :fileName => attachment.file.filename.to_s)]
  end

  def outgoing_id(result) = result['messageId']
  def media_location(payload) = [payload.fetch('url'), {}]

  private

  def instance_path
    "/instances/#{ERB::Util.url_encode(config.fetch('instance_id'))}/token/#{ERB::Util.url_encode(config.fetch('token'))}"
  end
end
