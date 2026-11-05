require 'rails_helper'

describe AiBrain::OwnerMessageJob do
  let(:account) { create(:account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999990000', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  # Created before the provider is stubbed: creating a channel validates its provider config.
  let!(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:owner_user) { create(:user, account: account, role: :administrator) }
  let(:owner) { AiBrainOwner.create!(account: account, user: owner_user, phone_number: '+5551995684103') }
  let(:message) { { 'id' => 'wamid.1', 'type' => 'text', 'text' => 'conecta o Google Drive' } }
  let(:client) { instance_double(AiBrain::Client) }
  let(:provider) { instance_double(Whatsapp::Providers::WhatsappTestService) }
  let(:job) { described_class.new }
  let(:sent) { [] }

  before do
    allow(AiBrain::Client).to receive(:new).and_return(client)
    allow(Whatsapp::Providers::WhatsappTestService).to receive(:new).and_return(provider)
    allow(provider).to receive(:send_text) { |to, text| sent << [to, text] }
    allow(job).to receive(:sleep)
  end

  it 'sends the reply and then each follow-up as its own message, and tells the backend the inbox' do
    allow(client).to receive(:post).and_return(
      [200, { 'textToSend' => 'Vou te mandar o link.', 'followUps' => ['https://api.test/connect/abc', 'Depois me avise.'] }]
    )

    job.perform(inbox.id, owner.id, '5551995684103', message)

    expect(client).to have_received(:post).with('owner/messages', hash_including(ownerUserId: owner_user.id, inboxId: inbox.id))
    expect(sent).to eq([['5551995684103', 'Vou te mandar o link.'], ['5551995684103', 'https://api.test/connect/abc'],
                        ['5551995684103', 'Depois me avise.']])
    expect(job).to have_received(:sleep).with(1).twice
  end

  it 'sends only the reply when there are no follow-ups' do
    allow(client).to receive(:post).and_return([200, { 'textToSend' => 'Olá!' }])

    job.perform(inbox.id, owner.id, '5551995684103', message)

    expect(sent).to eq([['5551995684103', 'Olá!']])
    expect(job).not_to have_received(:sleep)
  end
end
