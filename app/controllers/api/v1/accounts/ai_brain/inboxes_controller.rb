class Api::V1::Accounts::AiBrain::InboxesController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render json: Current.account.inboxes.includes(:ai_brain_inbox).order(:name).map { |inbox|
      { id: inbox.id, name: inbox.name, channelType: inbox.channel_type,
        aiBrainInbox: inbox.ai_brain_inbox && { active: inbox.ai_brain_inbox.active? } }
    }
  end

  def update
    inbox = Current.account.inboxes.find(params[:inbox_id])
    active = ActiveModel::Type::Boolean.new.cast(params.fetch(:active, true))
    link = Current.account.ai_brain_inboxes.find_or_initialize_by(inbox: inbox)
    link.update!(active: active)
    render json: { active: link.active? }
  end

  def destroy
    inbox = Current.account.inboxes.find(params[:inbox_id])
    inbox.ai_brain_inbox&.destroy!
    head :no_content
  end
end
