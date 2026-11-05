/* global axios */
import ApiClient from '../ApiClient';

class RemindersAPI extends ApiClient {
  constructor() {
    super('ai_brain/reminders', { accountScoped: true });
  }

  create(reminder) {
    return axios.post(this.url, { reminder });
  }

  update(id, reminder) {
    return axios.put(`${this.url}/${id}`, { reminder });
  }

  setEnabled(id, isEnabled) {
    return axios.put(`${this.url}/${id}/enabled`, { isEnabled });
  }

  deliveries(id, params = { limit: 50 }) {
    return axios.get(`${this.url}/${id}/deliveries`, { params });
  }

  // Plans one occurrence now; the AI Brain sends it within a minute.
  runNow(id) {
    return axios.post(`${this.url}/${id}/run_now`);
  }

  // The {{placeholders}} each kind of reminder can use, and the starting texts.
  placeholders() {
    return axios.get(`${this.url}/placeholders`);
  }
}

export default new RemindersAPI();
