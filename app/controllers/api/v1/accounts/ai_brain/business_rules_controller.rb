class Api::V1::Accounts::AiBrain::BusinessRulesController < Api::V1::Accounts::AiBrain::BaseController
  def show
    render_upstream(client.get('business-rules'))
  end

  def update
    rules = params.require(:businessRules).permit(
      :isAiEnabled, :businessName, :assistantName, :timeZone, :enforceAllowlist, :globalInstructions,
      :aiProvider, :modelId, :temperature, :maxOutputTokens, :tone,
      :inactivityNudgeMinutes, :inactivityAutoCloseMinutes, :otherSessionInactivityMinutes, :personCloseRequiredMinutes, :chargeTiming,
      companyRules: [], prohibitedBehaviors: [],
      requiredOnboardingFields: [], optionalOnboardingFields: [],
      workingHours: [:defaultSlotDurationMinutes, {
        weekly: [:day, { intervals: [:start, :end] }],
        dateOverrides: [:date, { intervals: [:start, :end] }]
      }],
      paymentConfirmationTemplate: [:name, :language, :category, { bodyParameters: [] }]
    )
    status, body = client.put('business-rules', rules.to_h)
    # The bot that posts in this account takes the assistant's name the backend saved.
    AiBrain::BotSender.rename(Current.account, body['assistantName']) if status == 200 && body['assistantName'].present?
    render_upstream([status, body])
  end
end
