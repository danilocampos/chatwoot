require 'rails_helper'

RSpec.describe Channel::Whatsapp do
  let(:account) { create(:account, settings: { 'whatsapp_providers' => { 'zapi' => true } }) }
  let!(:config) { Whatsapp::ProviderConfiguration.create!(provider: 'zapi', enabled: true) }
  let(:channel) do
    build(:channel_whatsapp, account: account, provider: 'zapi',
                             provider_config: { 'instance_id' => 'instance', 'token' => 'private-token', 'client_token' => 'client-secret' })
  end

  it 'encrypts inbox secrets and redacts serialized state' do
    channel.save!
    expect(channel.reload.provider_config['token']).to eq('private-token')
    expect(channel[:provider_config]).not_to have_key('token')
    expect(channel.ciphertext_for(:provider_credentials)).not_to include('private-token')
    expect(channel.to_json).not_to include('private-token', 'client-secret', 'webhook_verify_token')
    channel.update!(provider_config: { 'token' => '', 'instance_id' => 'instance' })
    expect(channel.reload.provider_config['token']).to eq('private-token')
    channel.update!(provider_config: { 'token' => 'rotated-token', 'instance_id' => 'instance' })
    expect(channel.reload.provider_config['token']).to eq('rotated-token')
  end

  it 'blocks creation but permits existing channel updates when disabled' do
    channel.save!
    config.update!(enabled: false)
    expect(channel.update(provider_config: channel.provider_config)).to be true
    another = channel.dup
    another.phone_number = '+15551239999'
    expect(another).not_to be_valid
    expect(another.errors[:provider]).not_to be_empty
  end

  it 'rejects an account without the grant' do
    channel.account = create(:account)
    expect(channel).not_to be_valid
    expect(channel.errors[:provider]).not_to be_empty
  end

  it 'does not let a disabled provider be reactivated by pointing an existing inbox at a new instance' do
    channel.save!
    config.update!(enabled: false)
    expect(channel.update(provider_config: channel.provider_config.merge('token' => 'different-instance'))).to be false
    expect(channel.errors[:provider]).not_to be_empty
  end

  it 'encrypts secrets even when an internal caller saves without validation' do
    channel.save!
    channel.provider_config = channel.provider_config.merge('token' => 'new-secret')
    channel.save!(validate: false)
    expect(channel.reload[:provider_config]).not_to have_key('token')
    expect(channel.provider_config['token']).to eq('new-secret')
    expect(channel.ciphertext_for(:provider_credentials)).not_to include('new-secret')
  end
end
