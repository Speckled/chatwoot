# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBrainStaffConversation do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:staff_contact) { create(:contact, account: account, additional_attributes: { 'ai_brain_staff_inbox_ids' => [inbox.id] }) }

  it 'flags the conversations a staff contact starts later in the inbox their messages came through' do
    conversation = create(:conversation, account: account, inbox: inbox, contact: staff_contact)
    elsewhere = create(:conversation, account: account, inbox: create(:inbox, account: account), contact: staff_contact)
    other = create(:conversation, account: account, inbox: inbox)

    expect(conversation).to be_ai_brain_staff
    expect(elsewhere).not_to be_ai_brain_staff
    expect(other).not_to be_ai_brain_staff
    expect(account.conversations.ai_brain_staff).to contain_exactly(conversation)
    expect(account.conversations.without_ai_brain_staff).to contain_exactly(elsewhere, other)
  end

  it 'never assigns a staff conversation to an agent' do
    agent = create(:user, account: account, auto_offline: false)
    create(:inbox_member, inbox: inbox, user: agent)
    allow(Redis::Alfred).to receive(:rpoplpush).and_return(agent.id)

    staff = create(:conversation, account: account, inbox: inbox, contact: staff_contact, assignee: nil)
    client = create(:conversation, account: account, inbox: inbox, assignee: nil)

    expect(staff.reload.assignee).to be_nil
    expect(client.reload.assignee).to eq(agent)
  end
end
