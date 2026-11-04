require 'administrate/base_dashboard'

class AiBrainOwnerDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    account: Field::BelongsTo.with_options(order: 'name'),
    user: AccountAdministratorField,
    phone_number: PhoneNumberField,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    account
    user
    phone_number
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    account
    user
    phone_number
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    account
    user
    phone_number
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(ai_brain_owner)
    "AI Brain owner ##{ai_brain_owner.id}"
  end
end
