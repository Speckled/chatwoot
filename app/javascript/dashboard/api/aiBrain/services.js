/* global axios */
import ApiClient from '../ApiClient';

class ServicesAPI extends ApiClient {
  constructor() {
    super('ai_brain/services', { accountScoped: true });
  }

  // service is a backend slug: google-calendar or google-drive.
  getGoogleAuthUrl(service) {
    return axios.get(
      `${this.baseUrl()}/ai_brain/google_services/${service}/authorization_url`
    );
  }

  disconnectGoogle(service) {
    return axios.delete(
      `${this.baseUrl()}/ai_brain/google_services/${service}`
    );
  }

  // userId is the AI Brain user id of a professional connecting an account of their own; without it, the clinic's.
  getMercadoPagoAuthUrl(userId) {
    const path = userId
      ? `professionals/${userId}/authorization_url`
      : 'authorization_url';
    return axios.get(`${this.baseUrl()}/ai_brain/mercado_pago/${path}`);
  }

  disconnectMercadoPago(userId) {
    const path = userId ? `/professionals/${userId}` : '';
    return axios.delete(`${this.baseUrl()}/ai_brain/mercado_pago${path}`);
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

  createCalendar(userId, summary) {
    return axios.post(`${this.baseUrl()}/ai_brain/calendars`, {
      userId,
      summary,
    });
  }

  updateUser(chatwootUserId, data) {
    return axios.patch(
      `${this.baseUrl()}/ai_brain/users/${chatwootUserId}`,
      data
    );
  }
}

export default new ServicesAPI();
