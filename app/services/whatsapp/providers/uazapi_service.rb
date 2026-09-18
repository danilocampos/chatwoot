class Whatsapp::Providers::UazapiService < Whatsapp::Providers::SessionService
  def api_headers = { 'token' => config.fetch('token') }
  def status_path = '/instance/status'

  def connect
    request(:post, '/webhook', body: { enabled: true, url: callback_url, events: %w[connection messages messages_update],
                                       excludeMessages: %w[wasSentByApi], addUrlEvents: false, addUrlTypesMessages: false })
    response = request(:post, '/instance/connect', body: {})
    instance = response['instance'] || response
    session_state('connection' => instance['status'] == 'connected' ? 'open' : 'connecting', 'qr_data_url' => instance['qrcode'])
  end

  def outgoing_payload(phone, message)
    body = { number: phone, replyid: reply_id(message), track_id: "chatwoot:#{message.id}" }.compact
    attachment = message.attachments.first
    return ['/send/text', body.merge(text: message.outgoing_content)] unless attachment

    type = { 'file' => 'document' }.fetch(attachment.file_type, attachment.file_type)
    ['/send/media', body.merge(type: type, file: attachment_url(attachment), text: message.outgoing_content,
                               docName: attachment.file.filename.to_s)]
  end

  def outgoing_id(result) = result['messageid']

  def media_location(payload)
    response = request(:post, '/message/download', body: { id: payload.fetch('id'), return_link: true })
    [response.fetch('fileURL'), {}]
  end
end
