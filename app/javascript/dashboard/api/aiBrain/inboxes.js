/* global axios */
import ApiClient from '../ApiClient';

class InboxesAPI extends ApiClient {
  constructor() {
    super('ai_brain/inboxes', { accountScoped: true });
  }

  toggle(id, active) {
    return axios.put(`${this.url}/${id}`, { active });
  }

  unassign(id) {
    return this.delete(id);
  }

  // The inbox's approved WhatsApp templates, with their body text and parameter count.
  getTemplates(id) {
    return axios.get(`${this.url}/${id}/templates`);
  }
}

export default new InboxesAPI();
