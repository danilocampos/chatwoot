require 'rails_helper'

RSpec.describe 'Kanban API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let!(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: create(:contact, account: account, name: 'Maria', phone_number: '+5511999999999')
    )
  end
  let!(:hidden_conversation) { create(:conversation, account: account, inbox: other_inbox) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
  end

  describe 'custom funnels' do
    let(:funnel) { account.kanban_funnels.create!(name: 'Sales', stages: [{ id: 'proposal', name: 'Proposal' }]) }

    it 'transfers a conversation, scopes the board and export, and can return to the default funnel' do
      put "/api/v1/accounts/#{account.id}/kanban/#{conversation.display_id}/move",
          params: { funnel_id: funnel.id, status: 'proposal' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      expect(conversation.reload.custom_attributes['kanban_funnel_id']).to eq(funnel.id.to_s)

      get "/api/v1/accounts/#{account.id}/kanban", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body.dig('stats', 'total')).to eq(0)
      get "/api/v1/accounts/#{account.id}/kanban", params: { funnel_id: funnel.id }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body.dig('kanban_data', 'proposal').pluck('id')).to eq([conversation.display_id])
      get "/api/v1/accounts/#{account.id}/kanban/export",
          params: { funnel_id: funnel.id, status: 'proposal' }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['data'].pluck('conversation_id')).to eq([conversation.display_id])

      put "/api/v1/accounts/#{account.id}/kanban/#{conversation.display_id}/move",
          params: { funnel_id: '', status: 'novo_lead' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      expect(conversation.reload.custom_attributes).not_to have_key('kanban_funnel_id')
    end

    it 'rejects a foreign account funnel and a stage from the wrong funnel' do
      other = create(:account).kanban_funnels.create!(name: 'Private', stages: [{ id: 'proposal', name: 'Proposal' }])
      put "/api/v1/accounts/#{account.id}/kanban/#{conversation.display_id}/move",
          params: { funnel_id: other.id, status: 'proposal' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
      put "/api/v1/accounts/#{account.id}/kanban/#{conversation.display_id}/move",
          params: { funnel_id: funnel.id, status: 'qualificado' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(conversation.reload.custom_attributes).not_to have_key('kanban_funnel_id')
    end
  end

  describe 'GET /api/v1/accounts/:account_id/kanban' do
    it 'requires authentication' do
      get "/api/v1/accounts/#{account.id}/kanban"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns only conversations visible to the agent and defaults them to new leads' do
      get "/api/v1/accounts/#{account.id}/kanban", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('kanban_data', 'novo_lead').pluck('id')).to eq([conversation.display_id])
      expect(body.dig('kanban_data', 'novo_lead', 0, 'messages_count')).to eq(conversation.messages.count)
      visible_ids = body['kanban_data'].values.flatten.pluck('id')
      expect(visible_ids).not_to include(hidden_conversation.display_id)
    end

    it 'filters by contact name without treating wildcard characters as SQL wildcards' do
      get "/api/v1/accounts/#{account.id}/kanban",
          params: { search: '%' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('stats', 'total')).to eq(0)
    end
  end

  describe 'PUT /api/v1/accounts/:account_id/kanban/:id/move' do
    it 'moves a visible conversation and preserves its other custom attributes' do
      conversation.update!(custom_attributes: { 'source' => 'campaign' })

      put "/api/v1/accounts/#{account.id}/kanban/#{conversation.display_id}/move",
          params: { status: 'qualificado' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(conversation.reload.custom_attributes).to eq('source' => 'campaign', 'kanban_status' => 'qualificado')
    end

    it 'rejects an unknown status' do
      put "/api/v1/accounts/#{account.id}/kanban/#{conversation.display_id}/move",
          params: { status: 'unknown' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(conversation.reload.custom_attributes).not_to have_key('kanban_status')
    end

    it 'does not move a conversation from an inbox the agent cannot access' do
      put "/api/v1/accounts/#{account.id}/kanban/#{hidden_conversation.display_id}/move",
          params: { status: 'qualificado' },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
