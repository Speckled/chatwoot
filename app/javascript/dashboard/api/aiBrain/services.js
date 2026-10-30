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

  getUsers(params = {}) {
    return axios.get(`${this.baseUrl()}/ai_brain/users`, { params });
  }

  linkCalendarUser(calendarId, userId) {
    return axios.put(
      `${this.baseUrl()}/ai_brain/calendars/${encodeURIComponent(calendarId)}/user`,
      { userId: userId || null }
    );
  }
}

export default new ServicesAPI();
