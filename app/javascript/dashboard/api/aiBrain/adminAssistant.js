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

  send(text) {
    return axios.post(this.url, { text });
  }
}

export default new AdminAssistantAPI();
