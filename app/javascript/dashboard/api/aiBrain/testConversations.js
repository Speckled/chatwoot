/* global axios */
import ApiClient from '../ApiClient';

class TestConversationsAPI extends ApiClient {
  constructor() {
    super('ai_brain/test_conversations', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  getContacts(params = {}) {
    return axios.get(`${this.url}/contacts`, { params });
  }

  sendMessage(id, data) {
    return axios.post(`${this.url}/${id}/messages`, data);
  }
}

export default new TestConversationsAPI();
