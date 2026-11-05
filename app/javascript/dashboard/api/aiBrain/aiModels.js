/* global axios */
import ApiClient from '../ApiClient';

class AiModelsAPI extends ApiClient {
  constructor() {
    super('ai_brain/ai_models', { accountScoped: true });
  }

  getProviders() {
    return axios.get(`${this.url}/providers`);
  }

  // The backend caches the provider's list for an hour; refresh fetches it again.
  getModels(provider, { refresh = false } = {}) {
    return axios.get(
      `${this.url}/providers/${encodeURIComponent(provider)}/models`,
      { params: refresh ? { refresh: true } : {} }
    );
  }
}

export default new AiModelsAPI();
