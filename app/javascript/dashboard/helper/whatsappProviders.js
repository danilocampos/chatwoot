const PROVIDER_ALIASES = {
  whatsapp: 'whatsapp_cloud',
  whatsapp_manual: 'whatsapp_cloud',
  whatsapp_embedded: 'whatsapp_cloud',
  '360dialog': 'default',
};

export const providerId = key => PROVIDER_ALIASES[key] || key;
export const providerAllowed = (providers, key) =>
  providers.some(provider => provider.id === providerId(key));
