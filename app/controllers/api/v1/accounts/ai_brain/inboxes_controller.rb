class Api::V1::Accounts::AiBrain::InboxesController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render json: Current.account.inboxes.includes(:ai_brain_inbox).order(:name).map { |inbox|
      { id: inbox.id, name: inbox.name, channelType: inbox.channel_type,
        aiBrainInbox: inbox.ai_brain_inbox && { agentDefinitionId: inbox.ai_brain_inbox.agent_definition_id,
                                                active: inbox.ai_brain_inbox.active? } }
    }
  end

  def update
    agent_id = params.require(:agentDefinitionId).to_s
    raise ActionController::BadRequest, 'Invalid agentDefinitionId' unless agent_id.match?(UUID_REGEX)

    inbox = Current.account.inboxes.find(params[:inbox_id])
    status, agent = client.get("agents/#{agent_id}")
    return render_upstream([status, agent]) unless status == 200
    return render json: { error: 'Agent is inactive' }, status: :unprocessable_entity unless agent['isActive']

    link = Current.account.ai_brain_inboxes.find_or_initialize_by(inbox: inbox)
    link.update!(agent_definition_id: agent_id, active: params.fetch(:active, true))
    render json: { agentDefinitionId: link.agent_definition_id, active: link.active? }
  end

  def destroy
    inbox = Current.account.inboxes.find(params[:inbox_id])
    inbox.ai_brain_inbox&.destroy!
    head :no_content
  end
end
