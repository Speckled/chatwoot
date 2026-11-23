class AiBrainInbox < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  validates :inbox_id, uniqueness: true
  validate :inbox_belongs_to_account

  # An inbox the AI Brain stops serving stops being the admin assistant's, so alerts fall back (OwnersController#owner_inbox).
  before_save { self.owner_assistant = false unless active? }
  after_save :flag_staff_contacts, if: -> { active? && (previously_new_record? || saved_change_to_active?) }

  # Makes this the inbox the admin assistant sends its alerts to the owners through, and no other inbox of the account.
  # The account's rows are locked so two choices at once leave one chosen, not a unique index error. This row is read
  # again under the lock: another choice may have cleared its flag since it was loaded, and saving a flag that is
  # already true in memory would write nothing.
  def choose_for_owner_assistant!
    transaction do
      account.ai_brain_inboxes.lock.load
      reload
      previous = account.ai_brain_inboxes.where(owner_assistant: true).where.not(id: id)
      previous.update_all(owner_assistant: false, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations -- only the flag changes
      update!(owner_assistant: true)
    end
  end

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
