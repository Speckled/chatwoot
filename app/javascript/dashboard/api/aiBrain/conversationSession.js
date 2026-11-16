/* global axios */
import ApiClient from '../ApiClient';

// The AI Brain session of a conversation, for anyone who can see it: the inactivity prompt, the answer to it, and closing
// with a reason.
class AiBrainConversationSessionAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  show(conversationId) {
    return axios.get(`${this.url}/${conversationId}/ai_brain_session`);
  }

  answer(conversationId, solved) {
    return axios.post(`${this.url}/${conversationId}/ai_brain_session/answer`, {
      solved,
    });
  }

  close(conversationId, reason, note) {
    return axios.post(`${this.url}/${conversationId}/ai_brain_session/close`, {
      reason,
      note,
    });
  }
}

export default new AiBrainConversationSessionAPI();
