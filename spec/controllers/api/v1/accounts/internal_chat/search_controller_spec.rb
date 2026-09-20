require 'rails_helper'

RSpec.describe 'Internal Chat Search API', type: :request do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_account_agent) { create(:user, account: other_account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/internal_chat/search' do
    let(:public_channel) { create(:internal_chat_channel, :public_channel, account: account, name: 'general') }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/internal_chat/search", params: { q: 'foo' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as an agent of the account' do
      before do
        agent
        public_channel
      end

      it 'returns matching messages from accessible channels' do
        create(:internal_chat_message, account: account, channel: public_channel, sender: agent, content: 'planning the launch')

        get "/api/v1/accounts/#{account.id}/internal_chat/search",
            params: { q: 'planning' },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['messages'].map { |m| m['content'] }).to include('planning the launch')
      end

      it 'scopes results to the current account' do
        other_channel = create(:internal_chat_channel, :public_channel, account: other_account, name: 'other-general')
        create(:internal_chat_channel_member, channel: other_channel, user: other_account_agent)
        create(:internal_chat_message, account: other_account, channel: other_channel, sender: other_account_agent, content: 'cross account leak')

        get "/api/v1/accounts/#{account.id}/internal_chat/search",
            params: { q: 'cross account leak' },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['messages']).to be_empty
      end

    end
  end
end
