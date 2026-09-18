class Webhooks::WhatsappProviderEventsJob < ApplicationJob
  queue_as :high
  self.log_arguments = false
  class PendingMessage < StandardError; end
  retry_on PendingMessage, wait: :polynomially_longer, attempts: 5
  retry_on Whatsapp::Providers::SessionService::Error, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(channel_id, encrypted_payload, fingerprint)
    channel = Channel::Whatsapp.find(channel_id)
    return unless channel.session_provider? && channel.account.active? && channel.inbox
    return unless Digest::SHA256.hexdigest(channel.provider_config.to_json) == fingerprint

    payload = JSON.parse(ActiveRecord::Encryption.encryptor.decrypt(encrypted_payload))
    normalizer = Whatsapp::ProviderRegistry.fetch(channel.provider).service.sub('Providers::', 'ProviderEvents::').constantize
    normalizer.new(payload).events.each { |event| process_event(channel, event) }
  end

  private

  def process_event(channel, event)
    if event[:connection]
      channel.provider_service.session_state(event[:connection])
    elsif event[:status]
      message = channel.inbox.messages.find_by(source_id: event[:id])
      raise PendingMessage unless message

      Messages::StatusUpdateService.new(message, event[:status]).perform
    else
      # All session inbound paths share this row lock. Durable inbox-scoped dedup,
      # released on rollback, unlike a TTL lock that can discard a failed delivery.
      channel.inbox.with_lock do
        Whatsapp::SessionIncomingService.new(inbox: channel.inbox, params: event[:payload].with_indifferent_access,
                                             outgoing_echo: event[:echo]).perform
      end
    end
  end
end
