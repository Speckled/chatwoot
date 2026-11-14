/* global axios */
import ApiClient from '../ApiClient';

// The clinic's staff as the AI Brain keeps it: Chatwoot users and people without a login.
class StaffAPI extends ApiClient {
  constructor() {
    super('ai_brain/staff', { accountScoped: true });
  }

  setCapabilities(id, changes) {
    return axios.put(`${this.url}/${id}/capabilities`, changes);
  }

  setDescription(id, description) {
    return axios.put(`${this.url}/${id}/description`, description);
  }
}

export default new StaffAPI();
