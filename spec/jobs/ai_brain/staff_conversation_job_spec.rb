require 'rails_helper'

describe AiBrain::StaffConversationJob do
  let(:account) { create(:account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999990000', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  let(:inbox) do
    inbox = create(:inbox, account: account, channel: channel)
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox
  end
  let(:contact) do
    create(:contact, account: account, phone_number: '+5551999990002', additional_attributes: { 'ai_brain_staff_inbox_ids' => [inbox.id] })
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'oi') }
  let(:client) { instance_double(AiBrain::Client) }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'names the person by the contact’s number and posts the reply and each follow-up in the conversation as the bot' do
    allow(client).to receive(:post).and_return(
      [200, { 'textToSend' => 'Vou te mandar o link.', 'followUps' => ['https://api.test/connect/abc'] }]
    )

    described_class.perform_now(message.id)

    expect(client).to have_received(:post).with('owner/messages', {
                                                  phoneNumber: '+5551999990002', whatsAppMessageId: "chatwoot-#{message.id}", inboxId: inbox.id,
                                                  messageType: 'text', text: 'oi', audio: nil, channel: 'staff_conversation'
                                                })
    replies = conversation.messages.outgoing.order(:id)
    expect(replies.map(&:content)).to eq(['Vou te mandar o link.', 'https://api.test/connect/abc'])
    expect(replies.map(&:sender)).to all(eq(AiBrain::BotSender.for(account)))
    expect(conversation.reload.ai_brain_staff?).to be(true)
  end

  it 'sends a voice note as audio' do
    message.attachments.create!(account: account, file_type: :audio,
                                file: { io: StringIO.new('ogg'), filename: 'voz.ogg', content_type: 'audio/ogg' })
    message.update!(content: nil)
    allow(client).to receive(:post).and_return([200, { 'textToSend' => 'Entendi.' }])

    described_class.perform_now(message.id)

    expect(client).to have_received(:post).with('owner/messages', hash_including(
                                                                    messageType: 'audio', text: nil,
                                                                    audio: { data: Base64.strict_encode64('ogg'), contentType: 'audio/ogg' }
                                                                  ))
  end

  it 'posts nothing when the backend sends an empty reply' do
    allow(client).to receive(:post).and_return([200, { 'textToSend' => '' }])

    described_class.perform_now(message.id)

    expect(conversation.messages.outgoing).to be_empty
  end

  it 'retries while the backend is busy and apologizes when it never answers' do
    allow(client).to receive(:post).and_return([409, {}])
    message_id = message.id

    perform_enqueued_jobs { described_class.perform_later(message_id) }

    expect(client).to have_received(:post).exactly(6).times
    expect(conversation.messages.outgoing.pluck(:content)).to eq([I18n.t('ai_brain.owner.unavailable')])
  end
end
