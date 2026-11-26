# The audit list of changes made through the staff assistant: read-only, administrators only. The backend never sends a
# change's input, only the description read back at confirmation.
class Api::V1::Accounts::AiBrain::OwnerActionsController < Api::V1::Accounts::AiBrain::BaseController
  def index
    query = params.permit(:from, :to, :staff_user_id, :limit).to_h
    query['staffUserId'] = query.delete('staff_user_id')
    render_upstream(client.get('owner-actions', query.compact_blank))
  end
end
