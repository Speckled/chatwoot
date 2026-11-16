class Api::V1::Accounts::AiBrain::BusinessRulesController < Api::V1::Accounts::AiBrain::BaseController
  def show
    render_upstream(client.get('business-rules'))
  end

  def update
    rules = params.require(:businessRules).permit(
      :isAiEnabled, :businessName, :timeZone, :enforceAllowlist, :globalInstructions,
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
    render_upstream(client.put('business-rules', rules.to_h))
  end
end
