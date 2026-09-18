require 'rails_helper'

RSpec.describe Whatsapp::ProviderEvents do
  it 'normalizes Baileys text, sender, replies and delivery status' do
    body = { event: 'messages.upsert', data: { messages: [{ key: { id: 'message-1', remoteJid: '5511999999999@s.whatsapp.net', fromMe: false },
                                                            message: { extendedTextMessage: { text: 'Hello',
                                                                                              contextInfo: { stanzaId: 'prior' } } } }] } }
    event = Whatsapp::ProviderEvents::BaileysService.new(body).events.first
    expect(event.dig(:payload, :messages, 0)).to include(id: 'message-1', from: '5511999999999', context: { id: 'prior' })
    status = Whatsapp::ProviderEvents::BaileysService.new(event: 'messages.update', data: [{ key: { id: 'message-1' }, update: { status: 4 } }])
    expect(status.events).to eq([{ id: 'message-1', status: 'read' }])
  end

  it 'normalizes Z-API media and ignores group events' do
    body = { type: 'ReceivedCallback', messageId: 'z-1', phone: '5511999999999', image: { imageUrl: 'https://cdn.example.com/a.png' } }
    event = Whatsapp::ProviderEvents::ZapiService.new(body).events.first
    expect(event.dig(:payload, :messages, 0, :image, :url)).to eq('https://cdn.example.com/a.png')
    expect(Whatsapp::ProviderEvents::ZapiService.new(body.merge(isGroup: true)).events).to be_empty
  end

  it 'normalizes Uazapi and never mistakes encrypted media URLs for downloadable files' do
    body = { EventType: 'messages', message: { messageid: 'u-1', chatid: '5511999999999@s.whatsapp.net',
                                               messageType: 'ImageMessage', content: { URL: 'https://encrypted.example.com/file' } } }
    message = Whatsapp::ProviderEvents::UazapiService.new(body).events.first.dig(:payload, :messages, 0)
    expect(message[:image]).to include(id: 'u-1')
    expect(message[:image]).not_to have_key(:url)
  end
end
