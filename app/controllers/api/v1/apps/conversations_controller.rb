# Asks the person who has a quiet AI Brain conversation to act on it (LRB-85): whether the patient's issue is solved
# ('notice'), or to close it ('close_required').
class Api::V1::Apps::ConversationsController < Api::V1::Apps::BaseController
  def inactivity_prompt
    conversation = Conversation.find_by(id: params[:conversation_id])
    return render json: { error: 'Conversation not found' }, status: :not_found unless conversation&.ai_brain_session?

    stage = params.require(:stage).to_s
    minutes = params.require(:minutes).to_i
    unless stage.in?(AiBrain::InactivityPrompt::STAGES) && minutes.positive?
      return render json: { error: 'stage must be notice or close_required, with positive minutes' }, status: :unprocessable_entity
    end

    AiBrain::InactivityPrompt.new(conversation: conversation, stage: stage, minutes: minutes).perform
    head :no_content
  end
end
