class Whatsapp::Providers::BaileysService < Whatsapp::Providers::SessionService
  def api_headers
    { 'x-api-key' => config.fetch('api_key') }
  end

  def status_path = '/status/auth'

  def connect
    request(:post, connection_path, body: {
              clientName: config['client_name'], webhookUrl: callback_url,
              webhookVerifyToken: config.fetch('webhook_verify_token'), includeMedia: false, groupsEnabled: false, syncFullHistory: false
            })
    session_state('connection' => 'connecting')
  end

  def outgoing_payload(phone, message)
    content = { text: message.outgoing_content }
    if (attachment = message.attachments.first)
      content = attachment_payload(attachment, message.outgoing_content)
    end
    content[:contextInfo] = { stanzaId: reply_id(message), participant: "#{phone}@s.whatsapp.net" } if reply_id(message).present?
    ["#{connection_path}/send-message", { jid: "#{phone}@s.whatsapp.net", messageContent: content,
                                          chatwootMessageId: "#{message.id}:#{message.created_at.to_i}" }]
  end

  def outgoing_id(result) = result.dig('data', 'key', 'id')

  def media_location(payload)
    id = ERB::Util.url_encode(payload.fetch('id'))
    ["#{configuration.effective_settings.fetch('base_url').chomp('/')}/media/#{id}", api_headers]
  end

  private

  def attachment_payload(attachment, caption)
    raise Error, I18n.t('whatsapp_providers.media_failed') if attachment.file.byte_size > 40.megabytes

    kind = { 'file' => 'document' }.fetch(attachment.file_type, attachment.file_type)
    buffer = attachment.file.blob.open { |file| Base64.strict_encode64(file.read) }
    { kind => buffer, 'caption' => caption, 'mimetype' => attachment.file.content_type, 'fileName' => attachment.file.filename.to_s }
  end

  def connection_path
    "/connections/#{ERB::Util.url_encode(whatsapp_channel.phone_number)}"
  end
end
