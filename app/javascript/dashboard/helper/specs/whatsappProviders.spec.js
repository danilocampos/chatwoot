import { providerAllowed, providerId } from '../whatsappProviders';

describe('WhatsApp provider eligibility', () => {
  it('maps all official setup paths to the same server grant', () => {
    [
      'whatsapp',
      'whatsapp_cloud',
      'whatsapp_manual',
      'whatsapp_embedded',
    ].forEach(key => {
      expect(providerId(key)).toBe('whatsapp_cloud');
      expect(providerAllowed([{ id: 'whatsapp_cloud' }], key)).toBe(true);
      expect(providerAllowed([], key)).toBe(false);
    });
  });
  it('never allows unsupported or ungranted URL-selected providers', () => {
    expect(providerAllowed([{ id: 'zapi' }], 'baileys')).toBe(false);
    expect(providerAllowed([], 'unknown')).toBe(false);
    expect(providerAllowed([{ id: 'default' }], '360dialog')).toBe(true);
  });
});
