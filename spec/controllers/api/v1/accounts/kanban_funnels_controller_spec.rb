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
    expect(response).to have_http_status(:unauthorized)
    patch "#{url}/#{own.id}", params: { funnel: { name: 'No' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not update another account funnel' do
    other = create(:account).kanban_funnels.create!(name: 'Private', stages: stages)
    patch "#{url}/#{other.id}", params: { funnel: { name: 'No' } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
    expect(other.reload.name).to eq('Private')
  end

  it 'rejects blank names, empty stages, and more than twenty stages' do
    [
      { name: ' ', stages: stages },
      { name: 'Sales', stages: [] },
      { name: 'Sales', stages: [{ id: 'new', name: ' ' }] },
      { name: 'Sales', stages: Array.new(21) { |i| { id: i.to_s, name: i.to_s } } }
    ].each do |funnel|
      post url, params: { funnel: funnel }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(account.kanban_funnels.count).to eq(0)
  end

  it 'preserves occupied stages while allowing renaming and reordering' do
    funnel = account.kanban_funnels.create!(name: 'Sales', stages: stages)
    create(:conversation, account: account, custom_attributes: { kanban_funnel_id: funnel.id.to_s, kanban_status: 'won' })
    patch "#{url}/#{funnel.id}", params: { funnel: { stages: [stages.first] } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(funnel.reload.stage_ids).to eq(%w[new won])
    updated = [{ id: 'won', name: 'Converted' }, stages.first]
    patch "#{url}/#{funnel.id}", params: { funnel: { stages: updated } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(funnel.reload.stage_ids).to eq(%w[won new])
  end
end
