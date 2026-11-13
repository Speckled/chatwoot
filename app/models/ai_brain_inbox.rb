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
  # to every contact flagged as staff, including those flagged while no inbox was active (an empty list); their
  # conversations there are staff-only from then on. Former staff have no key (Apps::StaffController#destroy_contact).
  # A contact that no longer passes validation is skipped rather than blocking the switch.
  def flag_staff_contacts
    return unless inbox.channel_type == 'Channel::Whatsapp'

    key = AiBrainStaffConversation::STAFF_INBOXES_KEY
    account.contacts.where("jsonb_typeof(contacts.additional_attributes->'#{key}') = 'array'").find_each do |contact|
      flagged = Array(contact.additional_attributes[key])
      next if flagged.include?(inbox_id)

      contact.update(additional_attributes: contact.additional_attributes.merge(key => flagged | [inbox_id]))
    end
  end
end
