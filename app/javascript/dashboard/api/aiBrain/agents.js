/* global axios */
import ApiClient from '../ApiClient';

class AgentsAPI extends ApiClient {
  constructor() {
    super('ai_brain/agents', { accountScoped: true });
  }

  getOptions() {
    return axios.get(`${this.url}/options`);
  }

  create(agent) {
    return axios.post(this.url, { agent });
  }

  update(id, agent, expectedVersion) {
    return axios.put(`${this.url}/${id}`, { agent, expectedVersion });
  }
}

export default new AgentsAPI();
