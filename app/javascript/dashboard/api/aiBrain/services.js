/* global axios */
import ApiClient from '../ApiClient';

class ServicesAPI extends ApiClient {
  constructor() {
    super('ai_brain/services', { accountScoped: true });
  }

  getGoogleAuthUrl() {
    return axios.get(
      `${this.baseUrl()}/ai_brain/google_calendar/authorization_url`
    );
  }

  disconnectGoogle() {
    return axios.delete(`${this.baseUrl()}/ai_brain/google_calendar`);
  }

  getCalendars() {
    return axios.get(`${this.baseUrl()}/ai_brain/calendars`);
  }
}

export default new ServicesAPI();
