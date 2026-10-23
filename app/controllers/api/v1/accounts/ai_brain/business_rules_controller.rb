class Api::V1::Accounts::AiBrain::BusinessRulesController < Api::V1::Accounts::AiBrain::BaseController
  def show
    render_upstream(client.get('business-rules'))
  end

  def update
    rules = params.require(:businessRules).permit(:isAiEnabled, :businessName, :timeZone, :enforceAllowlist,
                                                  :globalInstructions, companyRules: [], prohibitedBehaviors: [],
                                                                       workingHours: [:startTime, :endTime, :defaultSlotDurationMinutes,
                                                                                      { activeDays: [], blackoutDates: [] }])
    render_upstream(client.put('business-rules', rules.to_h))
  end
end
