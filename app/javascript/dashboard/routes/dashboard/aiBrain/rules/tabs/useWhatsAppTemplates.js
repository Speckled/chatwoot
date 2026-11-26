import { computed, onMounted, ref, watch } from 'vue';
import inboxesAPI from 'dashboard/api/aiBrain/inboxes';

const WHATSAPP = 'Channel::Whatsapp';

// The approved WhatsApp templates the template pickers offer. Templates belong to a WhatsApp number, so they are listed
// from one of the AI Brain's WhatsApp inboxes, the first unless another is chosen.
export function useWhatsAppTemplates() {
  const inboxes = ref([]);
  const inboxId = ref(null);
  const templates = ref([]);

  const inboxOptions = computed(() =>
    inboxes.value.map(inbox => ({
      value: inbox.id,
      label: inbox.phoneNumber
        ? `${inbox.name} (${inbox.phoneNumber})`
        : inbox.name,
    }))
  );

  const loadTemplates = async id => {
    templates.value = [];
    if (!id) return;
    try {
      templates.value = (await inboxesAPI.getTemplates(id)).data;
    } catch (error) {
      templates.value = [];
    }
  };

  onMounted(async () => {
    try {
      inboxes.value = (await inboxesAPI.get()).data.filter(
        inbox => inbox.channelType === WHATSAPP && inbox.aiBrainInbox?.active
      );
    } catch (error) {
      inboxes.value = [];
    }
    inboxId.value = inboxes.value[0]?.id ?? null;
  });
  watch(inboxId, loadTemplates);

  return { inboxId, inboxOptions, templates };
}
