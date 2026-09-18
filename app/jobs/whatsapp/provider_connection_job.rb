class Whatsapp::ProviderConnectionJob < ApplicationJob
  queue_as :default

  def perform(channel)
    return unless channel.inbox && channel.account.active? && channel.session_provider?
    return unless channel.provider_connection['activated'] || Whatsapp::ProviderRegistry.available?(channel.provider, channel.account)

    channel.provider_service.connect
    channel.update!(provider_connection: channel.provider_connection.merge('activated' => true))
  rescue Whatsapp::Providers::SessionService::Error
    channel.update!(provider_connection: channel.provider_connection.merge('connection' => 'close',
                                                                           'error' => I18n.t('whatsapp_providers.connection_failed')))
  end
end
