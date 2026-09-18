# Preserve 4.18's contact resolution, conversations, replies, media and message events.
class Whatsapp::SessionIncomingService < Whatsapp::IncomingMessageBaseService
  private

  def find_message_by_source_id(source_id)
    @message = inbox.messages.find_by(source_id: source_id) if source_id.present?
  end

  # The caller holds the inbox row lock throughout processing and persistence.
  def lock_message_source_id! = true

  def attach_files
    return if %w[text button interactive location contacts unsupported].include?(message_type)

    payload = messages_data.first.fetch(message_type)
    @message.content ||= payload[:caption]
    inbox.channel.provider_service.media_file(payload.stringify_keys) do |file|
      @message.attachments.build(account_id: inbox.account_id, file_type: file_content_type(message_type),
                                 file: { io: file.tempfile, filename: file.filename, content_type: file.content_type })
      @message.save!
    end
  end

  def create_message(message, **options)
    super
    timestamp = message[:timestamp].to_i
    @message.created_at = Time.zone.at(timestamp) if timestamp.positive? && timestamp <= Time.current.to_i + 300
  end
end
