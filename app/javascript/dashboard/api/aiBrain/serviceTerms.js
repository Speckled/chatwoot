/* global axios */
import ApiClient from '../ApiClient';

class ServiceTermsAPI extends ApiClient {
  constructor() {
    super('ai_brain/service_terms', { accountScoped: true });
  }

  update(serviceTerms) {
    return axios.put(this.url, { serviceTerms });
  }

  // userId is the AI Brain user id, not the Chatwoot one.
  updateProfessional(userId, serviceTerms) {
    return axios.put(`${this.url}/professionals/${userId}`, { serviceTerms });
  }
}

export default new ServiceTermsAPI();
