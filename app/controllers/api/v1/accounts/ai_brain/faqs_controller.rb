class Api::V1::Accounts::AiBrain::FaqsController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('faqs'))
  end

  def show
    render_upstream(client.get("faqs/#{uuid_param!}"))
  end

  def create
    render_upstream(client.post('faqs', faq_params))
  end

  def update
    render_upstream(client.put("faqs/#{uuid_param!}", faq_params))
  end

  def destroy
    render_upstream(client.delete("faqs/#{uuid_param!}"))
  end

  private

  def faq_params
    params.require(:faq).permit(:category, :title, :content, :isActive, tags: []).to_h
  end
end
