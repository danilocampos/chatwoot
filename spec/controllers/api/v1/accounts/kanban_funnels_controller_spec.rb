require 'rails_helper'

RSpec.describe 'Kanban funnels API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:stages) { [{ id: 'new', name: 'New' }, { id: 'won', name: 'Won' }] }
  let(:url) { "/api/v1/accounts/#{account.id}/kanban_funnels" }

  it 'requires authentication' do
    get url
    expect(response).to have_http_status(:unauthorized)
  end

  it 'lets an administrator create and rename a funnel' do
    post url, params: { funnel: { name: 'Sales', stages: stages } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body['id']
    patch "#{url}/#{id}", params: { funnel: { name: 'Support' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(account.kanban_funnels.find(id).name).to eq('Support')
  end

  it 'lets agents list only their account funnels and forbids configuration changes' do
    own = account.kanban_funnels.create!(name: 'Sales', stages: stages)
    create(:account).kanban_funnels.create!(name: 'Private', stages: stages)
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.pluck('id')).to eq([own.id])
    post url, params: { funnel: { name: 'No', stages: stages } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
    patch "#{url}/#{own.id}", params: { funnel: { name: 'No' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'does not update another account funnel' do
    other = create(:account).kanban_funnels.create!(name: 'Private', stages: stages)
    patch "#{url}/#{other.id}", params: { funnel: { name: 'No' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
    expect(other.reload.name).to eq('Private')
  end
end
