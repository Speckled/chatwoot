class AiBrainInbox < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  validates :inbox_id, uniqueness: true
  validate :inbox_belongs_to_account

  after_save :flag_staff_contacts, if: -> { active? && (previously_new_record? || saved_change_to_active?) }

  private

  def inbox_belongs_to_account
    errors.add(:inbox_id, :invalid) if inbox && inbox.account_id != account_id
  end

  # Staff are flagged in every AI Brain WhatsApp inbox of the account, so an inbox the AI Brain starts serving gets added
  # to every contact already flagged as staff; their conversations there are staff-only from then on.
  def flag_staff_contacts
    return unless inbox.channel_type == 'Channel::Whatsapp'

    key = AiBrainStaffConversation::STAFF_INBOXES_KEY
    account.contacts.where("jsonb_typeof(contacts.additional_attributes->'#{key}') = 'array'")
           .where("jsonb_array_length(contacts.additional_attributes->'#{key}') > 0").find_each do |contact|
      flagged = Array(contact.additional_attributes[key])
      next if flagged.include?(inbox_id)

      contact.update!(additional_attributes: contact.additional_attributes.merge(key => flagged | [inbox_id]))
    end
  end
end
