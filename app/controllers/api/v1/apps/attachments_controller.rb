# Lets the AI Brain backend download voice notes and store their transcripts, which the audio bubble shows.
class Api::V1::Apps::AttachmentsController < Api::V1::Apps::BaseController
  before_action :fetch_attachment

  # WhatsApp ingest uploads the file after the message commits, and the AI Brain can ask for it a moment earlier.
  rescue_from ActiveStorage::FileNotFoundError do
    response.set_header('Retry-After', '1')
    head :service_unavailable
  end

  def file
    send_data @attachment.file.download, type: @attachment.file.content_type, filename: @attachment.file.filename.to_s
  end

  def transcription
    @attachment.update!(meta: @attachment.meta.merge('transcribed_text' => params.require(:text)))
    @attachment.message.reload.send_update_event
    head :no_content
  end

  private

  def fetch_attachment
    @attachment = Attachment.audio.joins(message: { inbox: :ai_brain_inbox })
                            .where(ai_brain_inboxes: { active: true })
                            .find(params[:id])
  end
end
