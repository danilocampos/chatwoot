require 'rails_helper'

RSpec.describe Whatsapp::Providers::ZapiService do
  let(:channel) do
    build(:channel_whatsapp, provider: 'zapi', provider_config: { 'instance_id' => 'instance', 'token' => 'secret', 'client_token' => 'private' })
  end
  let(:service) { described_class.new(whatsapp_channel: channel) }
  let(:message) { build(:message, content: 'Hello', id: 51) }

  it 'sends text and returns the external message ID' do
    stub_request(:post, 'https://api.z-api.io/instances/instance/token/secret/send-text')
      .with(headers: { 'Client-Token' => 'private' }, body: { phone: '5511999999999', message: message.outgoing_content }.to_json)
      .to_return(status: 200, body: { messageId: 'external-1' }.to_json)
    expect(service.send_message('+5511999999999', message)).to eq('external-1')
  end

  it 'does not expose provider error bodies or credentials' do
    stub_request(:get, 'https://api.z-api.io/instances/instance/token/secret/status').to_return(status: 401, body: 'private-secret')
    expect { service.test_connection }.to raise_error(Whatsapp::Providers::SessionService::Error) { |error|
      expect(error.message).not_to include('private-secret')
    }
  end

  it 'reports an uncertain send on timeout without automatically retrying' do
    stub_request(:post, 'https://api.z-api.io/instances/instance/token/secret/send-text').to_timeout
    expect { service.send_message('+5511999999999', message) }.to raise_error(Whatsapp::Providers::SessionService::OutcomeUnknown) do |error|
      expect(error.cause).to be_nil
    end
  end
end
