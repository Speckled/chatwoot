class Api::V1::Accounts::AiBrain::ServiceTermsController < Api::V1::Accounts::AiBrain::BaseController
  def show
    render_upstream(client.get('service-terms'))
  end

  def update
    render_upstream(client.put('service-terms', service_terms_params))
  end

  # What one professional changes from the clinic's terms. A list left out reaches the backend as unset, which means the
  # clinic's; an empty list means none.
  def update_professional
    render_upstream(client.put("users/#{uuid_param!(:user_id)}/service-terms", service_terms_params))
  end

  private

  def service_terms_params
    params.require(:serviceTerms).permit(
      :notes,
      services: [:id, :name, :price, :priceOnRequest, :offered],
      acceptedPlans: [],
      paymentMethods: [:type, { pix: [:key, :recipientName] }]
    ).to_h
  end
end
