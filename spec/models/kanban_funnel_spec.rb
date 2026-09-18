require 'rails_helper'

RSpec.describe KanbanFunnel do
  let(:account) { create(:account) }
  let(:stages) { [{ 'id' => 'new', 'name' => 'New' }, { 'id' => 'won', 'name' => 'Won' }] }
  let(:funnel) { described_class.create!(account: account, name: 'Sales', stages: stages) }

  it 'rejects malformed, empty and duplicated stage identifiers' do
    [nil, [], [{}], ['invalid'], [{ 'id' => '<script>', 'name' => 'Invalid' }], [stages.first, stages.first]].each do |invalid|
      record = described_class.new(account: account, name: 'Sales', stages: invalid)
      expect(record).not_to be_valid
    end
  end

  it 'keeps conversations attached to a renamed or reordered stage' do
    conversation = create(:conversation, account: account,
                                         custom_attributes: { kanban_funnel_id: funnel.id.to_s, kanban_status: 'new' })
    funnel.update!(stages: [stages.last, { 'id' => 'new', 'name' => 'Contacted' }])
    expect(conversation.reload.custom_attributes['kanban_status']).to eq('new')
    expect(funnel.stage_ids).to eq(%w[won new])
  end

  it 'rejects removal of occupied stages but allows empty stages to be removed' do
    create(:conversation, account: account, custom_attributes: { kanban_funnel_id: funnel.id.to_s, kanban_status: 'new' })
    funnel.stages = [stages.last]
    expect(funnel).not_to be_valid
    funnel.stages = [stages.first]
    expect(funnel).to be_valid
  end
end
