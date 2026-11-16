# frozen_string_literal: true

require 'rails_helper'

describe 'Filtered parameters' do # rubocop:disable RSpec/DescribeClass
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  # LRB-85: the note a person gives when closing an AI Brain conversation can hold patient data.
  it 'keeps the AI Brain close note out of the log, at the top level and wrapped' do
    params = { 'reason' => 'Other', 'note' => 'Paciente ligou' }
    filtered = filter.filter(params.merge('ai_brain_session' => params))

    expect(filtered).to eq('reason' => 'Other', 'note' => '[FILTERED]', 'ai_brain_session' => { 'reason' => 'Other', 'note' => '[FILTERED]' })
  end

  it 'leaves other keys that contain the word alone' do
    expect(filter.filter('notes_count' => 2, 'footnote' => 'x')).to eq('notes_count' => 2, 'footnote' => 'x')
  end

  it 'filters the note in the close request a person sends' do
    env = Rack::MockRequest.env_for('/close', params: { reason: 'Other', note: 'Paciente ligou' }).merge(Rails.application.env_config)
    request = ActionDispatch::Request.new(env)

    expect(request.filtered_parameters).to include('reason' => 'Other', 'note' => '[FILTERED]')
  end
end
