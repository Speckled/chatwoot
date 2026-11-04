require 'administrate/field/belongs_to'

# A user picked from the administrators of each account; the form shows only those of the selected account.
class AccountAdministratorField < Administrate::Field::BelongsTo
  # [label, user id, { data: { account_ids: } }] for every administrator, ready for a select.
  def administrator_options
    AccountUser.administrator.joins(:user).includes(:user).order('users.name').group_by(&:user).map do |user, memberships|
      ["#{user.name} (#{user.email})", user.id, { data: { account_ids: memberships.map(&:account_id).join(',') } }]
    end
  end
end
