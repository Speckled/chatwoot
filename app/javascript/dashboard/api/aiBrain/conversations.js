/* global axios */
import ApiClient from '../ApiClient';

class AiBrainConversationsAPI extends ApiClient {
  constructor() {
    super('ai_brain/conversations', { accountScoped: true });
  }

  endSession(id) {
    return axios.post(`${this.url}/${id}/end_session`);
  }

  validateReview(id, text) {
    return axios.post(`${this.url}/${id}/validate_review`, { text });
  }

  answerStaffQuestion(id, questionId, text, saveAsFaq = false) {
    return axios.post(
      `${this.url}/${id}/staff_questions/${questionId}/answer`,
      { text, saveAsFaq }
    );
  }
}

export default new AiBrainConversationsAPI();
