/* global axios */
import ApiClient from '../ApiClient';

class FaqsAPI extends ApiClient {
  constructor() {
    super('ai_brain/faqs', { accountScoped: true });
  }

  create(faq) {
    return axios.post(this.url, { faq });
  }

  update(id, faq) {
    return axios.put(`${this.url}/${id}`, { faq });
  }
}

export default new FaqsAPI();
