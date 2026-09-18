require 'rails_helper'

RSpec.describe 'Account WhatsApp providers', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user) }
  let!(:membership) { create(:account_user, account: account, user: admin, role: :administrator) }

  it 'returns only supported, globally enabled and granted providers without secrets' do
    Whatsapp::ProviderConfiguration.create!(provider: 'zapi', enabled: true)
    get "/api/v1/accounts/#{account.id}/whatsapp/providers", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.map { |entry| entry['id'] }).to contain_exactly('whatsapp_cloud', 'default', 'twilio')
    account.update!(settings: { 'whatsapp_providers' => { 'zapi' => true } })
    get "/api/v1/accounts/#{account.id}/whatsapp/providers", headers: admin.create_new_auth_token
    expect(response.parsed_body.map { |entry| entry['id'] }).to include('zapi')
    expect(response.body).not_to include('api_key', 'credentials', 'service')
  end

  it 'denies ordinary agents and does not allow self-granting through account settings' do
    membership.update!(role: :agent)
    get "/api/v1/accounts/#{account.id}/whatsapp/providers", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
    expect(account.reload.settings).not_to have_key('whatsapp_providers')
  end

  it 'enforces grants when creating inboxes through the existing API and does not serialize secrets' do
    Whatsapp::ProviderConfiguration.create!(provider: 'zapi', enabled: true)
    body = { name: 'Session', channel: { type: 'whatsapp', provider: 'zapi', phone_number: '+15551234567',
                                         provider_config: { instance_id: 'instance', token: 'inbox-secret', client_token: 'client-secret' } } }
    post "/api/v1/accounts/#{account.id}/inboxes", headers: admin.create_new_auth_token, params: body, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    account.update!(settings: { 'whatsapp_providers' => { 'zapi' => true } })
    post "/api/v1/accounts/#{account.id}/inboxes", headers: admin.create_new_auth_token, params: body, as: :json
    expect(response).to have_http_status(:success)
    expect(response.body).not_to include('inbox-secret', 'client-secret', 'webhook_verify_token')
    inbox = account.inboxes.last
    other_account = create(:account)
    create(:account_user, account: other_account, user: admin, role: :administrator)
    post "/api/v1/accounts/#{other_account.id}/whatsapp/providers/#{inbox.id}/test_connection", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
  end
end
