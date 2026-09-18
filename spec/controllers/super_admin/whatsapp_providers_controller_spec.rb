require 'rails_helper'

RSpec.describe 'Super Admin WhatsApp providers', type: :request do
  let(:super_admin) { create(:super_admin) }

  it 'rejects unauthenticated and ordinary account users' do
    get '/super_admin/whatsapp_providers'
    expect(response).to have_http_status(:redirect)
    sign_in(create(:user))
    patch '/super_admin/whatsapp_providers/zapi', params: { configuration: { enabled: '1' } }
    expect(response).to have_http_status(:redirect)
    expect(Whatsapp::ProviderConfiguration.count).to eq(0)
  end

  it 'renders admin forms without revealing saved secrets' do
    sign_in(super_admin, scope: :super_admin)
    Whatsapp::ProviderConfiguration.create!(provider: 'baileys', enabled: true,
                                            settings: { 'base_url' => 'https://wa.example.com' }, credentials: { 'api_key' => 'never-reveal-me' })
    get '/super_admin/whatsapp_providers'
    expect(response).to have_http_status(:ok)
    get '/super_admin/whatsapp_providers/baileys'
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('never-reveal-me')
  end

  it 'saves access only for the selected account, including revoking every grant' do
    sign_in(super_admin, scope: :super_admin)
    account = create(:account)
    other = create(:account)
    patch '/super_admin/whatsapp_providers/update_account', params: { account_id: account.id, providers: { zapi: '1' } }
    expect(response).to have_http_status(:redirect)
    expect(account.reload.settings.dig('whatsapp_providers', 'zapi')).to be true
    expect(other.reload.settings).not_to have_key('whatsapp_providers')
    patch '/super_admin/whatsapp_providers/update_account', params: { account_id: account.id }
    expect(account.reload.settings['whatsapp_providers'].values).to all(be false)
  end

  it 'updates secrets without reflecting them in the response or audit' do
    sign_in(super_admin, scope: :super_admin)
    patch '/super_admin/whatsapp_providers/baileys', params: {
      configuration: { enabled: '1', base_url: 'https://wa.example.com', api_key: 'sensitive-key' }
    }
    expect(response).to have_http_status(:redirect)
    expect(Whatsapp::ProviderConfiguration.find_by!(provider: 'baileys').credentials['api_key']).to eq('sensitive-key')
    expect(response.body).not_to include('sensitive-key')
    expect(Enterprise::AuditLog.last.audited_changes.to_json).not_to include('sensitive-key') if defined?(Enterprise::AuditLog)
  end
end
