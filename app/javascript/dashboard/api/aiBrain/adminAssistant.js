/* global axios */
import ApiClient from '../ApiClient';

// The admin assistant: the same conversation as the owner's WhatsApp, from the dashboard drawer.
class AdminAssistantAPI extends ApiClient {
  constructor() {
    super('ai_brain/admin_assistant', { accountScoped: true });
  }

  history() {
    return axios.get(this.url, { params: { limit: 50 } });
  }

  // Starts a turn; the reply is read with reply(requestId), which answers 202 until it is ready.
  send(text) {
    return axios.post(this.url, { text });
  }

  reply(requestId) {
    return axios.get(`${this.url}/${requestId}`);
  }
}

export default new AdminAssistantAPI();
