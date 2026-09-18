require 'rails_helper'

RSpec.describe Whatsapp::Providers::SessionService do
  let(:message) { build(:message, content: 'Hello', id: 51) }
  let(:base_url) { 'https://93.184.216.34' }

  it 'sends Baileys text with stable idempotency metadata' do
    Whatsapp::ProviderConfiguration.create!(provider: 'baileys', enabled: true,
                                            settings: { base_url: base_url }, credentials: { api_key: 'private' })
    channel = build(:channel_whatsapp, phone_number: '+15551234567', provider: 'baileys', provider_config: {})
    stub_request(:post, "#{base_url}/connections/%2B15551234567/send-message")
      .with(headers: { 'X-Api-Key' => 'private' })
      .to_return(status: 200, body: { data: { key: { id: 'b-1' } } }.to_json)
    expect(channel.provider_service.send_message('5511999999999', message)).to eq('b-1')
  end

  it 'sends Uazapi media using a downloadable URL and captures its external ID' do
    Whatsapp::ProviderConfiguration.create!(provider: 'uazapi', enabled: true, settings: { base_url: base_url })
    channel = build(:channel_whatsapp, provider: 'uazapi', provider_config: { token: 'private' })
    attachment = instance_double(Attachment, with_attached_file?: true, file_type: 'image', download_url: 'https://cdn.example.com/image.png')
    allow(attachment).to receive(:file).and_return(instance_double(ActiveStorage::Blob, filename: 'image.png'))
    allow(message).to receive(:attachments).and_return([attachment])
    stub_request(:post, "#{base_url}/send/media").with(headers: { 'Token' => 'private' })
                                                 .to_return(status: 200, body: { messageid: 'u-1' }.to_json)
    expect(channel.provider_service.send_message('5511999999999', message)).to eq('u-1')
  end

  it 'rejects private destinations unless explicitly trusted by Super Admin' do
    Whatsapp::ProviderConfiguration.create!(provider: 'uazapi', enabled: true, settings: { base_url: 'https://127.0.0.1' })
    channel = build(:channel_whatsapp, provider: 'uazapi', provider_config: { token: 'private' })
    expect { channel.provider_service.test_connection }.to raise_error(Whatsapp::Providers::SessionService::Error)
  end

  it 'never follows a redirect carrying credentials' do
    Whatsapp::ProviderConfiguration.create!(provider: 'uazapi', enabled: true, settings: { base_url: base_url })
    channel = build(:channel_whatsapp, provider: 'uazapi', provider_config: { token: 'private' })
    stub_request(:get, "#{base_url}/instance/status").to_return(status: 302, headers: { 'Location' => 'https://untrusted.example.com' })
    expect { channel.provider_service.test_connection }.to raise_error(Whatsapp::Providers::SessionService::Error)
    expect(WebMock).not_to have_requested(:get, 'https://untrusted.example.com')
  end
end
