/* global axios */
import ApiClient from '../ApiClient';

class InboxesAPI extends ApiClient {
  constructor() {
    super('ai_brain/inboxes', { accountScoped: true });
  }

  assign(id, agentDefinitionId) {
    return axios.put(`${this.url}/${id}`, { agentDefinitionId, active: true });
  }

  unassign(id) {
    return this.delete(id);
  }
}

export default new InboxesAPI();
