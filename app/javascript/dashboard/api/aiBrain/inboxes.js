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
}

export default new InboxesAPI();
