class Whatsapp::ProviderEvents::ZapiService < Whatsapp::ProviderEvents::Base
  MEDIA = { 'image' => 'imageUrl', 'audio' => 'audioUrl', 'video' => 'videoUrl', 'document' => 'documentUrl', 'sticker' => 'stickerUrl' }.freeze
  STATUSES = { 'SENT' => 'sent', 'DELIVERED' => 'delivered', 'RECEIVED' => 'delivered', 'READ' => 'read',
               'READ_BY_ME' => 'read', 'PLAYED' => 'read', 'FAILED' => 'failed' }.freeze

  def events
    case @body[:type]
    when 'ReceivedCallback' then [received].compact
    when 'MessageStatusCallback'
      status = STATUSES[@body[:status].to_s.upcase]
      status ? Array(@body[:ids]).map { |id| { id: id, status: status } } : []
    when 'ConnectedCallback' then [{ connection: { 'connection' => 'open' } }]
    when 'DisconnectedCallback' then [{ connection: { 'connection' => 'close' } }]
    else []
    end
  end

  private

  def received
    return if %w[isGroup isNewsletter broadcast isStatusReply].any? { |key| @body[key] }

    kind = MEDIA.keys.find { |key| @body.key?(key) }
    data = @body[kind] || {}
    type = kind || 'text'
    media = { url: data[MEDIA[kind]], caption: data[:caption] } if kind
    message_event(id: @body[:messageId], phone: @body[:phone], text: @body.dig(:text, :message), type: type, media: media,
                  name: @body[:senderName], echo: @body[:fromMe] == true, timestamp: @body[:momment],
                  reply: @body[:referenceMessageId])
  end
end
