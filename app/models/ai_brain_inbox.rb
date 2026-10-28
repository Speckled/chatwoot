class AiBrainInbox < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  validates :inbox_id, uniqueness: true
  validate :inbox_belongs_to_account

  private

  def inbox_belongs_to_account
    errors.add(:inbox_id, :invalid) if inbox && inbox.account_id != account_id
  end
end
