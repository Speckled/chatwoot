/* global axios */
import ApiClient from '../ApiClient';

class PaymentsAPI extends ApiClient {
  constructor() {
    super('ai_brain/payments', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  refund(id) {
    return axios.post(`${this.url}/${id}/refund`);
  }
}

export default new PaymentsAPI();
