class Whatsapp::ProviderEvents::UazapiService < Whatsapp::ProviderEvents::Base
  MEDIA = { 'ImageMessage' => 'image', 'VideoMessage' => 'video', 'AudioMessage' => 'audio',
            'DocumentMessage' => 'document', 'StickerMessage' => 'sticker' }.freeze
  STATES = { 'connected' => 'open', 'connecting' => 'connecting', 'disconnected' => 'close' }.freeze

  def events
    case @body[:EventType]
    when 'messages' then [received].compact
    when 'messages_update'
      status = { 'Delivered' => 'delivered', 'Read' => 'read', 'Played' => 'read' }[@body[:state]]
      status ? Array(@body.dig(:event, :MessageIDs)).map { |id| { id: id, status: status } } : []
    when 'connection'
      instance = @body.fetch(:instance, {})
      [{ connection: { 'connection' => STATES.fetch(instance[:status], 'close'), 'qr_data_url' => instance[:qrcode] }.compact }]
    else []
    end
  end

  private

  def received
    message = @body.fetch(:message, {})
    return unless message[:chatid].to_s.end_with?('@s.whatsapp.net')
    return if message.values_at(:edited, :reaction).any?(&:present?)

    data = message[:content].is_a?(Hash) ? message[:content] : {}
    type = MEDIA.fetch(message[:messageType], 'text')
    media = { id: message[:messageid], caption: data[:caption] || message[:text] } if type != 'text'
    message_event(id: message[:messageid], phone: message[:chatid], text: message[:text], type: type, media: media,
                  name: message[:senderName], echo: message[:fromMe] == true, timestamp: message[:messageTimestamp],
                  reply: quoted_id(message))
  end

  def quoted_id(message)
    message[:quoted].is_a?(Hash) ? message.dig(:quoted, :messageid) : message[:quoted]
  end
end
