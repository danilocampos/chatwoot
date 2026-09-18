class Whatsapp::ProviderEvents::BaileysService < Whatsapp::ProviderEvents::Base
  MEDIA = { 'imageMessage' => 'image', 'audioMessage' => 'audio', 'videoMessage' => 'video',
            'documentMessage' => 'document', 'stickerMessage' => 'sticker' }.freeze
  STATUSES = { 0 => 'failed', 1 => 'sent', 2 => 'sent', 3 => 'delivered', 4 => 'read', 5 => 'read' }.freeze

  def events
    case @body[:event]
    when 'messages.upsert' then Array(@body.dig(:data, :messages)).filter_map { |message| message_event_for(message) }
    when 'messages.update'
      Array(@body[:data]).filter_map do |update|
        status = STATUSES[update.dig(:update, :status)]
        { id: update.dig(:key, :id), status: status } if status
      end
    when 'connection.update'
      data = @body.fetch(:data, {})
      [{ connection: { 'connection' => data[:connection], 'qr_data_url' => data[:qrDataUrl] }.compact }]
    else []
    end
  end

  private

  def message_event_for(message)
    key = message.fetch(:key, {})
    jid = phone_jid(key)
    return unless jid

    content = message.fetch(:message, {})
    media_key = MEDIA.keys.find { |type| content.key?(type) }
    data = media_key ? content[media_key] : content.fetch(:extendedTextMessage, {})
    type = MEDIA.fetch(media_key, 'text')
    media = { id: key[:id], caption: data[:caption] } if media_key
    message_event(id: key[:id], phone: jid, text: content[:conversation] || data[:text], type: type, media: media,
                  name: message[:pushName], echo: key[:fromMe] == true, timestamp: message[:messageTimestamp],
                  reply: data.dig(:contextInfo, :stanzaId))
  end

  def phone_jid(key)
    [key[:remoteJid], key[:remoteJidAlt]].find { |value| value.to_s.end_with?('@s.whatsapp.net') }
  end
end
