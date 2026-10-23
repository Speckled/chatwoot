/* global axios */
import ApiClient from '../ApiClient';

class BusinessRulesAPI extends ApiClient {
  constructor() {
    super('ai_brain/business_rules', { accountScoped: true });
  }

  update(businessRules) {
    return axios.put(this.url, { businessRules });
  }
}

export default new BusinessRulesAPI();
