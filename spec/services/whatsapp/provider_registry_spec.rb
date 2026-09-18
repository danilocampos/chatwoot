require 'rails_helper'

RSpec.describe Whatsapp::ProviderRegistry do
  let(:account) { create(:account) }

  it 'preserves official defaults and requires explicit session access' do
    expect(described_class.available?('whatsapp_cloud', account)).to be true
    expect(described_class.available?('baileys', account)).to be false
    expect(described_class.available?('unknown', account)).to be false
  end

  it 'requires both global and account permission and isolates accounts' do
    config = Whatsapp::ProviderConfiguration.create!(provider: 'zapi', enabled: true)
    account.update!(settings: { 'whatsapp_providers' => { 'zapi' => true } })
    expect(described_class.available?('zapi', account)).to be true
    expect(described_class.available?('zapi', create(:account))).to be false
    config.update!(enabled: false)
    expect(described_class.available?('zapi', account)).to be false
  end
end
