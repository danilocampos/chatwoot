/* global axios */
import ApiClient from './ApiClient';

class WhatsappProviders extends ApiClient {
  constructor() {
    super('whatsapp/providers', { accountScoped: true });
  }

  connect(inboxId) {
    return axios.post(`${this.url}/${inboxId}/connect`);
  }

  testConnection(inboxId) {
    return axios.post(`${this.url}/${inboxId}/test_connection`);
  }
}

export default new WhatsappProviders();
