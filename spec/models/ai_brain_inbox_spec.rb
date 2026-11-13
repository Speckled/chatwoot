# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBrainInbox do
  let(:account) { create(:account) }
  let(:key) { AiBrainStaffConversation::STAFF_INBOXES_KEY }
  let(:flagged_inbox) { create(:inbox, account: account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999991111', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  let(:inbox) { create(:inbox, account: account, channel: channel) }
  let!(:staff) { create(:contact, account: account, phone_number: '+5511977776666', additional_attributes: { key => [flagged_inbox.id] }) }
  let!(:former_staff) { create(:contact, account: account, phone_number: '+5511977775555', additional_attributes: { key => [] }) }
  let!(:patient) { create(:contact, account: account, phone_number: '+5511977774444') }

  it 'flags every staff contact of the account in a WhatsApp inbox the AI Brain starts serving' do
    described_class.create!(account: account, inbox: inbox, active: true)

    expect(staff.reload.additional_attributes[key]).to contain_exactly(flagged_inbox.id, inbox.id)
    expect(former_staff.reload.additional_attributes[key]).to eq([])
    expect(patient.reload.additional_attributes).not_to have_key(key)
  end

  it 'flags staff when a paused inbox is turned back on, not while it is off' do
    link = described_class.create!(account: account, inbox: inbox, active: false)
    expect(staff.reload.additional_attributes[key]).to eq([flagged_inbox.id])

    link.update!(active: true)

    expect(staff.reload.additional_attributes[key]).to contain_exactly(flagged_inbox.id, inbox.id)
  end

  it 'leaves inboxes of other channels alone' do
    described_class.create!(account: account, inbox: create(:inbox, account: account), active: true)

    expect(staff.reload.additional_attributes[key]).to eq([flagged_inbox.id])
  end
end
