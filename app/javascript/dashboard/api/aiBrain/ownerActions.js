/* global axios */
import ApiClient from '../ApiClient';

class OwnerActionsAPI extends ApiClient {
  constructor() {
    super('ai_brain/owner_actions', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new OwnerActionsAPI();
