class AiBrainPolicy < ApplicationPolicy
  def manage?
    account_user&.administrator? || false
  end
end
