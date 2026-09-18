import WhatsappProvidersAPI from '../whatsappProviders';

describe('WhatsApp providers authenticated API client', () => {
  const originalAxios = window.axios;

  beforeEach(() => {
    window.axios = { get: vi.fn(), post: vi.fn() };
    vi.spyOn(WhatsappProvidersAPI, 'accountIdFromRoute', 'get').mockReturnValue(
      '42'
    );
  });

  afterEach(() => {
    window.axios = originalAxios;
    vi.restoreAllMocks();
  });

  it('uses the shared authenticated client and current account for the catalog', () => {
    WhatsappProvidersAPI.get();
    expect(window.axios.get).toHaveBeenCalledWith(
      '/api/v1/accounts/42/whatsapp/providers'
    );
  });

  it('scopes connection operations to the selected inbox', () => {
    WhatsappProvidersAPI.connect(7);
    WhatsappProvidersAPI.testConnection(7);
    expect(window.axios.post).toHaveBeenCalledWith(
      '/api/v1/accounts/42/whatsapp/providers/7/connect'
    );
    expect(window.axios.post).toHaveBeenCalledWith(
      '/api/v1/accounts/42/whatsapp/providers/7/test_connection'
    );
  });
});
