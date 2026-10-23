class Api::V1::Accounts::AiBrain::AgentsController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('agents'))
  end

  def options
    render_upstream(client.get('agents/options'))
  end

  def show
    render_upstream(client.get("agents/#{uuid_param!}"))
  end

  def create
    render_upstream(client.post('agents', agent_params))
  end

  def update
    render_upstream(client.put("agents/#{uuid_param!}", { expectedVersion: params.require(:expectedVersion), agent: agent_params }))
  end

  def destroy
    agent_id = uuid_param!
    result = client.delete("agents/#{agent_id}")
    Current.account.ai_brain_inboxes.where(agent_definition_id: agent_id).destroy_all if result.first == 204
    render_upstream(result)
  end

  private

  def agent_params
    params.require(:agent).permit(:name, :description, :isActive,
                                  config: [:provider, :modelId, :temperature, :maxOutputTokens, :systemInstructions, :tone,
                                           :reviewPolicy, { guardrailRules: [], capabilities: [], enabledTools: [], toolParameters: {} }]).to_h
  end
end
