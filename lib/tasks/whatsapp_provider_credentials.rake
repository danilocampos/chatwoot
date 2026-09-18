namespace :whatsapp do
  desc 'Encrypt existing WhatsApp credentials in batches (requires configured encryption keys)'
  task encrypt_provider_credentials: :environment do
    abort 'Configure Active Record encryption keys first' unless Chatwoot.encryption_configured?

    count = 0
    Channel::Whatsapp.find_each do |channel|
      channel.with_lock do
        next unless (channel[:provider_config] || {}).keys.intersect?(WhatsappProviderCredentials::SECRET_KEYS)

        channel.send(:protect_provider_credentials)
        # No remote credential validation, webhook mutation or template synchronization.
        # rubocop:disable Rails/SkipsModelValidations
        channel.update_columns(provider_config: channel[:provider_config], provider_credentials: channel.provider_credentials)
        # rubocop:enable Rails/SkipsModelValidations
        count += 1
      end
    end
    puts "Encrypted credentials for #{count} WhatsApp channels. Keep encryption keys backed up."
  end
end
