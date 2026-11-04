# WhatsApp Flow CSAT survey

A WhatsApp Cloud inbox can send its CSAT survey as a WhatsApp Flow: a form that opens inside the chat, with a 1–5 rating and an optional comment. The patient never leaves WhatsApp, and the answer is saved as a normal CSAT response, so Reports → CSAT and the conversation's survey bubble work as before.

## How it works

The survey goes out when a conversation is resolved, as today: by an agent, or by the AI Brain when it closes the session.

- **Inside the 24-hour customer service window**, the survey message is sent as an interactive Flow message. The body is the inbox's CSAT message and the button is its CSAT button text.
- **Outside the window**, an approved message template with a Flow button is sent instead, if one is attached.
- **With neither**, the inbox falls back to its existing CSAT behaviour: a URL template or a "not sent" activity.

The Flow is endpointless, so it needs no keys, server or extra URL. Its `flow_token` is `csat:<conversation uuid>`.

When the patient submits, WhatsApp sends an `nfm_reply`, and `Whatsapp::CsatFlowService` writes the answer to the conversation's survey message. No message is created, so the resolved conversation is not reopened and the bot does not reply. Submissions more than 14 days after the survey was sent are dropped, matching the web survey.

## 1. Build the Flow in WhatsApp Manager

1. Go to WhatsApp Manager → Account tools → Flows → **Create flow**. Pick the **Survey** category and start from a blank Flow.
2. In the JSON editor, paste the Flow JSON below. Adjust the texts if you like, but keep the field names, which are the contract with Chatwoot:
   - `rating` is required and its option ids must be the strings `"1"` to `"5"`.
   - `comment` is optional.
   - The Footer must use `complete` with the payload shown.
3. Check the preview, then **Publish** the Flow and note its Flow ID.

```json
{
  "version": "7.3",
  "screens": [
    {
      "id": "RATING",
      "title": "Avalie o atendimento",
      "terminal": true,
      "success": true,
      "layout": {
        "type": "SingleColumnLayout",
        "children": [
          { "type": "TextSubheading", "text": "Como foi seu atendimento?" },
          {
            "type": "RadioButtonsGroup",
            "name": "rating",
            "label": "Sua nota",
            "required": true,
            "data-source": [
              { "id": "5", "title": "😍 Excelente" },
              { "id": "4", "title": "🙂 Bom" },
              { "id": "3", "title": "😐 Regular" },
              { "id": "2", "title": "🙁 Ruim" },
              { "id": "1", "title": "😞 Péssimo" }
            ]
          },
          {
            "type": "TextArea",
            "name": "comment",
            "label": "Comentário",
            "required": false,
            "helper-text": "Opcional: conte o que podemos melhorar"
          },
          {
            "type": "Footer",
            "label": "Enviar",
            "on-click-action": {
              "name": "complete",
              "payload": { "rating": "${form.rating}", "comment": "${form.comment}" }
            }
          }
        ]
      }
    }
  ]
}
```

## 2. Create the Flow template (outside the window)

1. Go to WhatsApp Manager → Message templates → **Create template**. Choose the **Utility** category; Meta may recategorize a survey as Marketing.
2. Write a body, for example "Olá! Como foi seu atendimento? Toque no botão para avaliar."
3. Add a **Complete Flow** button that opens the published CSAT Flow on its `RATING` screen.
4. Submit the template, then note its name and language (e.g. `pt_BR`). It is only used once it is `APPROVED`.

You can skip this step: surveys inside the window still use the Flow.

## 3. Attach the Flow to the inbox

First, enable CSAT and save the inbox's **Customer Satisfaction** settings page; the Flow's button uses that page's button text. Then run:

```bash
docker compose exec chatwoot-web bundle exec rails "whatsapp:csat_flow:attach[INBOX_ID,FLOW_ID,TEMPLATE_NAME,TEMPLATE_LANGUAGE]"
```

The template arguments are optional. The task checks that the inbox is a WhatsApp Cloud inbox and the Flow is `PUBLISHED`, prints the template's status, and stores `whatsapp_flow` in the inbox's `csat_config`. Saving the Customer Satisfaction page keeps it.

To go back to the link survey:

```bash
docker compose exec chatwoot-web bundle exec rails "whatsapp:csat_flow:detach[INBOX_ID]"
```

## Changing the Flow

Messages already sent keep the Flow version they were sent with. To change the form, edit the Flow in WhatsApp Manager and publish it again, keeping the field names. If you replace it with a new Flow, run `attach` again with the new Flow ID.
