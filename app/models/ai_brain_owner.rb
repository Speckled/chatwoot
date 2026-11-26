# A clinic owner who changes the app by messaging the company WhatsApp number. Only the installation console grants it,
# and only to administrators of the account. Their WhatsApp messages go to the AI Brain and are never stored in Chatwoot.
class AiBrainOwner < ApplicationRecord
  belongs_to :account
  belongs_to :user

  before_validation { self.phone_number = self.class.canonical_phone_number(phone_number) }

  validates :phone_number, presence: true, uniqueness: true, format: { with: /\A\+[1-9]\d{1,14}\z/ }
  validate :user_is_administrator

  # Owner access lasts only while the user is still an administrator of the account.
  def self.for_sender(account, wa_id)
    return unless wa_id.to_s.match?(/\A\d{1,15}\z/)

    owner = account.ai_brain_owners.find_by(phone_number: canonical_phone_number(wa_id))
    owner if owner&.administrator?
  end

  # E.164 after the country fixes WhatsApp ingest applies, e.g. adding the Brazilian mobile 9.
  def self.canonical_phone_number(number)
    digits = number.to_s.delete('^0-9')
    return if digits.empty?

    normalizer = Whatsapp::PhoneNumberNormalizationService::NORMALIZERS.map(&:new).find { |candidate| candidate.handles_country?(digits) }
    "+#{normalizer ? normalizer.normalize(digits) : digits}"
  end

  def administrator?
    account.account_users.administrator.exists?(user_id: user_id)
  end

  # Records a message the owner wrote to an inbox: alerts go through it while the account has chosen none, and WhatsApp's
  # 24-hour window counts from it. Written without validations: an owner who stopped being an administrator since the
  # message arrived still gets the backend's answer. An older message, such as a retried turn, keeps the later time.
  def wrote_to!(inbox_id, at)
    latest = [last_incoming_at_in(inbox_id), at].compact.max
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(last_inbox_id: inbox_id, last_incoming_at: last_incoming_at.merge(inbox_id.to_s => latest.iso8601))
    # rubocop:enable Rails/SkipsModelValidations
  end

  def last_incoming_at_in(inbox_id)
    last_incoming_at[inbox_id.to_s]&.then { |at| Time.zone.parse(at) }
  end

  private

  def user_is_administrator
    errors.add(:user, :not_administrator) if account && user && !administrator?
  end
end
