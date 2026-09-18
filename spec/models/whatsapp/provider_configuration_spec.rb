require 'rails_helper'

RSpec.describe Whatsapp::ProviderConfiguration do
  let(:config) { described_class.new(provider: 'baileys') }

  it 'encrypts credentials and preserves a secret on blank update' do
    config.assign_configuration('enabled' => true, 'base_url' => 'https://wa.example.com', 'api_key' => 'private-value')
    config.save!
    expect(config.ciphertext_for(:credentials)).not_to include('private-value')
    expect(config.reload.credentials['api_key']).to eq('private-value')
    config.assign_configuration('api_key' => '')
    config.save!
    expect(config.reload.credentials['api_key']).to eq('private-value')
    expect(config.to_json).not_to include('private-value')
  end

  it 'rejects invalid endpoints, missing credentials and unknown providers' do
    config.assign_configuration('enabled' => true, 'base_url' => 'file:///etc/passwd')
    expect(config).not_to be_valid
    expect(described_class.new(provider: 'arbitrary')).not_to be_valid
  end

  it 'gives persisted settings precedence over legacy ENV' do
    with_modified_env BAILEYS_PROVIDER_DEFAULT_URL: 'https://old.example.com', BAILEYS_PROVIDER_DEFAULT_API_KEY: 'old-key' do
      config.assign_configuration('base_url' => 'https://new.example.com', 'api_key' => 'new-key')
      expect(config.effective_settings.values_at('base_url', 'api_key')).to eq(['https://new.example.com', 'new-key'])
    end
  end
end
