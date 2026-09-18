require 'rails_helper'

RSpec.describe 'Session provider webhooks', type: :request do
  let(:account) { create(:account, settings: { 'whatsapp_providers' => { 'zapi' => true } }) }
  let(:channel) do
    create(:channel_whatsapp, provider: 'zapi', account: account,
                              provider_config: { 'instance_id' => 'instance', 'token' => 'secret', 'client_token' => 'private' })
  end

  before { Whatsapp::ProviderConfiguration.create!(provider: 'zapi', enabled: true) }

  it 'authenticates before enqueueing and strips authentication data' do
    path = "/webhooks/whatsapp_providers/zapi/#{channel.id}"
    post path, params: { instanceId: 'instance', token: 'secret' }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect do
      post "#{path}?webhook_token=#{channel.provider_config['webhook_verify_token']}",
           params: { instanceId: 'instance', token: 'secret', type: 'ReceivedCallback' }, as: :json
    end.to have_enqueued_job(Webhooks::WhatsappProviderEventsJob)
    expect(response).to have_http_status(:ok)
    expect(enqueued_jobs.last[:args].to_json).not_to include('secret', 'webhook_token')
    body = ActiveRecord::Encryption.encryptor.decrypt(enqueued_jobs.last[:args][1])
    expect(body).not_to include('secret', 'webhook_token')
    expect(JSON.parse(body)['type']).to eq('ReceivedCallback')
  end

  it 'rejects unknown providers and inboxes' do
    post '/webhooks/whatsapp_providers/unknown/1', params: {}, as: :json
    expect(response).to have_http_status(:not_found)
    post '/webhooks/whatsapp_providers/zapi/0', params: {}, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'requires both the Uazapi callback secret and the instance token' do
    Whatsapp::ProviderConfiguration.create!(provider: 'uazapi', enabled: true, settings: { base_url: 'https://93.184.216.34' })
    account.update!(settings: { 'whatsapp_providers' => { 'uazapi' => true } })
    instance = create(:channel_whatsapp, provider: 'uazapi', account: account, provider_config: { token: 'instance-secret' })
    url = "/webhooks/whatsapp_providers/uazapi/#{instance.id}?webhook_token=#{instance.provider_config['webhook_verify_token']}"
    post url, params: { EventType: 'connection', token: 'wrong' }, as: :json
    expect(response).to have_http_status(:unauthorized)
    post url, params: { EventType: 'connection', token: 'instance-secret' }, as: :json
    expect(response).to have_http_status(:ok)
    expect(enqueued_jobs.last[:args].to_json).not_to include('instance-secret')
  end

  it 'requires the Baileys callback verification token and strips it before enqueueing' do
    Whatsapp::ProviderConfiguration.create!(provider: 'baileys', enabled: true,
                                            settings: { base_url: 'https://93.184.216.34' }, credentials: { api_key: 'global-secret' })
    account.update!(settings: { 'whatsapp_providers' => { 'baileys' => true } })
    instance = create(:channel_whatsapp, provider: 'baileys', account: account, provider_config: {})
    secret = instance.provider_config['webhook_verify_token']
    url = "/webhooks/whatsapp_providers/baileys/#{instance.id}?webhook_token=#{secret}"
    post url, params: { event: 'connection.update', webhookVerifyToken: 'wrong' }, as: :json
    expect(response).to have_http_status(:unauthorized)
    qr = 'data:image/png;base64,cGFpcmluZw=='
    post url, params: { event: 'connection.update', webhookVerifyToken: secret,
                        data: { connection: 'connecting', qrDataUrl: qr } }, as: :json
    expect(response).to have_http_status(:ok)
    arguments = enqueued_jobs.last[:args]
    expect(arguments.to_json).not_to include(secret, qr)
    Webhooks::WhatsappProviderEventsJob.perform_now(*arguments)
    expect(instance.reload.provider_credentials['qr_data_url']).to eq(qr)
    expect(instance.provider_connection).not_to have_key('qr_data_url')
    expect(instance.provider_config).not_to have_key('qr_data_url')
    expect(instance.ciphertext_for(:provider_credentials)).not_to include(qr)
  end
end
