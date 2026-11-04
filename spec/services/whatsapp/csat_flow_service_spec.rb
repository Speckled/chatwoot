require 'rails_helper'

describe Whatsapp::CsatFlowService do
  let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { whatsapp_channel.inbox }
  let(:contact) { create(:contact, account: inbox.account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '2423423243') }
  let(:conversation) { create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: :resolved) }
  let!(:survey_message) do
    create(:message, conversation: conversation, inbox: inbox, message_type: :template, content_type: :input_csat, content: 'Rate us')
  end
  let(:flow_response) { { 'flow_token' => described_class.flow_token(conversation), 'rating' => '2', 'comment' => 'Long wait' } }
  let(:service) { described_class.new(inbox: inbox, contact: contact, flow_response: flow_response) }

  describe '#perform' do
    it 'records the rating and comment on the survey message' do
      expect(service.perform).to be true

      expect(survey_message.reload.submitted_values).to eq(
        'csat_survey_response' => { 'rating' => 2, 'feedback_message' => 'Long wait' }
      )
    end

    it 'records a rating without a comment' do
      flow_response['comment'] = ''

      service.perform

      expect(survey_message.reload.submitted_values['csat_survey_response']).to eq('rating' => 2, 'feedback_message' => nil)
    end

    it 'leaves responses of other Flows to the caller' do
      flow_response['flow_token'] = 'booking:123'

      expect(service.perform).to be false
      expect(survey_message.reload.submitted_values).to be_nil
    end

    it 'drops a CSAT response for a conversation of another contact' do
      other_service = described_class.new(inbox: inbox, contact: create(:contact, account: inbox.account), flow_response: flow_response)

      expect(other_service.perform).to be true
      expect(survey_message.reload.submitted_values).to be_nil
    end

    it 'drops a CSAT response sent after the survey is locked' do
      survey_message.update!(created_at: 15.days.ago)

      expect(service.perform).to be true
      expect(survey_message.reload.submitted_values).to be_nil
    end
  end
end
