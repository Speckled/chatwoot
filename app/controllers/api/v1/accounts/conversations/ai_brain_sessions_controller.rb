# The AI Brain session of a conversation, for anyone who can see the conversation (LRB-85): the inactivity prompt it shows,
# the person's answer to the question whether the patient's issue is solved, and closing it with a reason.
class Api::V1::Accounts::Conversations::AiBrainSessionsController < Api::V1::Accounts::Conversations::BaseController
  CLOSE_REASONS = %w[IssueSolved PatientStoppedReplying HandledElsewhere Other].freeze
  MAX_NOTE_LENGTH = 500

  rescue_from AiBrain::Client::UnavailableError do
    render json: { error: I18n.t('ai_brain.errors.unavailable') }, status: :bad_gateway
  end

  def show
    state = @conversation.ai_brain_conversation
    render json: { aiSession: @conversation.ai_brain_session?, inactivityPrompt: state&.inactivity_prompt,
                   promptedAt: state&.inactivity_prompted_at&.to_i }
  end

  # Either answer restarts the backend's clock toward the mandatory close. Yes then offers to close; No offers to message
  # the patient, or to close without contacting them.
  def answer
    return render_error('no_inactivity_question', :unprocessable_entity) unless params.key?(:solved)

    solved = ActiveModel::Type::Boolean.new.cast(params[:solved])
    @conversation.with_lock do
      state = @conversation.ai_brain_conversation
      return render_error('no_inactivity_question', :conflict) unless state&.inactivity_prompt == 'notice'

      status, = client.post("conversations/#{@conversation.id}/session/inactivity-answer")
      if status == 409
        state.show_inactivity_prompt!(nil)
        return render_error('no_inactivity_question', :conflict)
      end
      raise AiBrain::Client::UnavailableError, "Answering the inactivity question failed with HTTP #{status}" unless status == 204

      state.show_inactivity_prompt!(solved ? 'solved' : 'unsolved')
    end
    head :no_content
  end

  # A person closes the conversation from the dashboard: the backend records the reason and who closed, then the conversation
  # is resolved. The patient is sent nothing. A close because the patient stopped replying is a close for inactivity, so it
  # sends no satisfaction survey either; the other reasons keep it.
  def close
    reason = params[:reason].to_s
    note = params[:note].to_s.strip
    return render_error('no_ai_session', :unprocessable_entity) unless @conversation.ai_brain_session?
    return render_error('invalid_close_reason', :unprocessable_entity) unless valid_reason?(reason, note)

    @conversation.with_lock do
      status, = client.post("conversations/#{@conversation.id}/session/end",
                            { reason: reason, note: reason == 'Other' ? note : nil, closedByUserId: Current.user.id }.compact)
      raise AiBrain::Client::UnavailableError, "Ending the session failed with HTTP #{status}" unless status == 204

      unless @conversation.resolved?
        silently = reason == 'PatientStoppedReplying'
        silently ? @conversation.ai_brain_resolve_silently! : @conversation.update!(status: :resolved)
      end
    end
    head :no_content
  end

  private

  def valid_reason?(reason, note)
    reason.in?(CLOSE_REASONS) && (reason != 'Other' || note.present?) && note.length <= MAX_NOTE_LENGTH
  end

  def render_error(key, status)
    render json: { error: I18n.t("ai_brain.errors.#{key}") }, status: status
  end

  def client
    @client ||= AiBrain::Client.new
  end
end
