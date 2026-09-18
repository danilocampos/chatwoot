require 'rails_helper'

RSpec.describe Webhooks::WhatsappProviderEventsJob do
  let(:account) { create(:account, settings: { 'whatsapp_providers' => { 'zapi' => true } }) }
  let!(:configuration) { Whatsapp::ProviderConfiguration.create!(provider: 'zapi', enabled: true) }
  let(:channel) do
    create(:channel_whatsapp, provider: 'zapi', account: account,
                              provider_config: { 'instance_id' => 'instance', 'token' => 'secret', 'client_token' => 'private' })
  end
  let(:payload) { { 'type' => 'ReceivedCallback', 'messageId' => 'incoming-1', 'phone' => '5511999999999', 'text' => { 'message' => 'Hello' } } }
  let(:encrypted_payload) { ActiveRecord::Encryption.encryptor.encrypt(payload.to_json) }

  it 'persists text once despite webhook redelivery and continues after global disable' do
    fingerprint = Digest::SHA256.hexdigest(channel.provider_config.to_json)
    configuration.update!(enabled: false)
    expect do
      2.times { described_class.perform_now(channel.id, encrypted_payload, fingerprint) }
    end.to change { channel.inbox.messages.count }.by(1)
    expect(channel.inbox.messages.last).to have_attributes(content: 'Hello', source_id: 'incoming-1', message_type: 'incoming')
  end

  it 'rejects an event authenticated before credentials changed' do
    fingerprint = Digest::SHA256.hexdigest(channel.provider_config.to_json)
    channel.update!(provider_config: channel.provider_config.merge('token' => 'rotated'))
    expect { described_class.perform_now(channel.id, encrypted_payload, fingerprint) }.not_to(change { channel.inbox.messages.count })
  end

  it 'updates delivery statuses without regressing read to delivered' do
    message = create(:message, inbox: channel.inbox, account: account, source_id: 'outgoing-1', status: :read)
    fingerprint = Digest::SHA256.hexdigest(channel.provider_config.to_json)
    body = { type: 'MessageStatusCallback', ids: [message.source_id], status: 'DELIVERED' }
    described_class.perform_now(channel.id, ActiveRecord::Encryption.encryptor.encrypt(body.to_json), fingerprint)
    expect(message.reload.status).to eq('read')
  end

  it 'persists downloaded media, its caption and timestamp once' do
    timestamp = 1.hour.ago.to_i
    media = payload.except('text').merge('momment' => timestamp * 1000,
                                         'image' => { 'imageUrl' => 'https://cdn.example.com/photo.png', 'caption' => 'Photo' })
    fingerprint = Digest::SHA256.hexdigest(channel.provider_config.to_json)
    File.open(Rails.root.join('spec/assets/sample.png')) do |file|
      allow(SafeFetch).to receive(:fetch).and_yield(SafeFetch::Result.new(tempfile: file, filename: 'photo.png', content_type: 'image/png'))
      2.times { described_class.perform_now(channel.id, ActiveRecord::Encryption.encryptor.encrypt(media.to_json), fingerprint) }
    end
    message = channel.inbox.messages.find_by!(source_id: 'incoming-1')
    expect(message.content).to eq('Photo')
    expect(message.created_at.to_i).to eq(timestamp)
    expect(message.attachments.count).to eq(1)
    expect(message.attachments.first.file).to be_attached
  end
end
