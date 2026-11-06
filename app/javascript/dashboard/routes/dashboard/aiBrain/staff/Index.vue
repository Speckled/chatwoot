<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import staffAPI from 'dashboard/api/aiBrain/staff';

// Everyone who works with the clinic: Chatwoot users and people without a login, such as a service provider the clinic
// only messages on WhatsApp. Owners of the clinic change what each one may do.
const { t } = useI18n();
const staff = ref([]);
const loading = ref(true);
const saving = ref(false);
const dialogRef = ref(null);
const emptyProvider = () => ({
  name: '',
  whatsAppNumber: '',
  email: '',
  bookable: false,
  responder: false,
});
const provider = ref(emptyProvider());

const errorOf = error => error?.response?.data?.error || t('AI_BRAIN.ERROR');
const load = async () => {
  try {
    staff.value = (await staffAPI.get()).data;
  } catch (error) {
    useAlert(errorOf(error));
  } finally {
    loading.value = false;
  }
};

const replace = changed => {
  const index = staff.value.findIndex(item => item.id === changed.id);
  if (index !== -1) staff.value.splice(index, 1, changed);
};
const setCapability = async (member, key, value) => {
  try {
    replace((await staffAPI.setCapabilities(member.id, { [key]: value })).data);
  } catch (error) {
    useAlert(errorOf(error));
    await load();
  }
};
const openProvider = () => {
  provider.value = emptyProvider();
  dialogRef.value?.open();
};
const addProvider = async () => {
  saving.value = true;
  try {
    const created = (await staffAPI.create(provider.value)).data;
    staff.value = [...staff.value, created].sort((a, b) =>
      a.name.localeCompare(b.name)
    );
    dialogRef.value?.close();
  } catch (error) {
    useAlert(errorOf(error));
  } finally {
    saving.value = false;
  }
};
const remove = async member => {
  if (
    !window.confirm(t('AI_BRAIN.STAFF.CONFIRM_REMOVE', { name: member.name }))
  )
    return;
  try {
    await staffAPI.delete(member.id);
    staff.value = staff.value.filter(item => item.id !== member.id);
  } catch (error) {
    useAlert(errorOf(error));
  }
};
const loginLabel = member =>
  member.hasLogin
    ? t(`AI_BRAIN.STAFF.ROLES.${member.role}`)
    : t('AI_BRAIN.STAFF.NO_LOGIN');

onMounted(load);
</script>

<template>
  <SettingsLayout :is-loading="loading">
    <template #header>
      <BaseSettingsHeader
        :title="t('AI_BRAIN.STAFF.TITLE')"
        :description="t('AI_BRAIN.STAFF.DESCRIPTION')"
      >
        <template #actions>
          <Button
            type="button"
            color="blue"
            size="sm"
            icon="i-woot-plus"
            :label="t('AI_BRAIN.STAFF.ADD_PROVIDER')"
            @click="openProvider"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <table class="min-w-full table-auto divide-y divide-n-weak">
        <thead>
          <tr class="border-t border-n-weak">
            <th
              class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
            >
              {{ t('AI_BRAIN.STAFF.NAME') }}
            </th>
            <th
              class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
            >
              {{ t('AI_BRAIN.STAFF.LOGIN') }}
            </th>
            <th
              class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
            >
              {{ t('AI_BRAIN.STAFF.OWNER') }}
            </th>
            <th
              class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
            >
              {{ t('AI_BRAIN.STAFF.RESPONDER') }}
            </th>
            <th
              class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
            >
              {{ t('AI_BRAIN.STAFF.ASSISTANT') }}
            </th>
            <th
              class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
            >
              {{ t('AI_BRAIN.STAFF.BOOKABLE') }}
            </th>
            <th
              class="py-3 ltr:pr-4 rtl:pl-4 text-end text-sm font-medium text-n-slate-12"
            >
              {{ t('AI_BRAIN.ACTIONS') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak text-n-slate-11">
          <tr v-for="member in staff" :key="member.id">
            <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12">
              <div class="font-medium">
                {{ member.displayName || member.name }}
              </div>
              <div class="text-xs text-n-slate-11">
                {{
                  [member.email, member.whatsAppNumber]
                    .filter(Boolean)
                    .join(' · ')
                }}
              </div>
            </td>
            <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
              {{ loginLabel(member) }}
            </td>
            <td class="py-3 ltr:pr-4 rtl:pl-4">
              <Switch
                :model-value="member.isOwner"
                :disabled="member.role !== 'administrator'"
                @change="value => setCapability(member, 'isOwner', value)"
              />
            </td>
            <td class="py-3 ltr:pr-4 rtl:pl-4">
              <Switch
                :model-value="member.isResponder"
                @change="value => setCapability(member, 'isResponder', value)"
              />
            </td>
            <td class="py-3 ltr:pr-4 rtl:pl-4">
              <Switch
                :model-value="member.hasAssistantAccess"
                :disabled="member.role !== 'administrator'"
                @change="
                  value => setCapability(member, 'assistantAccess', value)
                "
              />
            </td>
            <td class="py-3 ltr:pr-4 rtl:pl-4">
              <Switch
                :model-value="member.requiresCalendar"
                :disabled="member.hasLogin"
                @change="value => setCapability(member, 'bookable', value)"
              />
            </td>
            <td class="py-3 ltr:pr-4 rtl:pl-4 text-end">
              <Button
                v-if="!member.hasLogin"
                type="button"
                size="xs"
                color="ruby"
                variant="faded"
                icon="i-lucide-trash-2"
                :aria-label="t('AI_BRAIN.STAFF.REMOVE')"
                @click="remove(member)"
              />
            </td>
          </tr>
        </tbody>
      </table>
      <p class="mt-4 text-xs text-n-slate-11">
        {{ t('AI_BRAIN.STAFF.HINT') }}
      </p>
      <Dialog
        ref="dialogRef"
        :title="t('AI_BRAIN.STAFF.ADD_PROVIDER')"
        :description="t('AI_BRAIN.STAFF.PROVIDER_HINT')"
        :confirm-button-label="t('AI_BRAIN.SAVE')"
        :cancel-button-label="t('AI_BRAIN.CANCEL')"
        :is-loading="saving"
        @confirm="addProvider"
      >
        <div class="flex flex-col gap-4">
          <WithLabel name="provider-name" :label="t('AI_BRAIN.STAFF.NAME')">
            <NextInput v-model="provider.name" class="w-full" />
          </WithLabel>
          <WithLabel
            name="provider-whatsapp"
            :label="t('AI_BRAIN.STAFF.WHATSAPP')"
          >
            <NextInput
              v-model="provider.whatsAppNumber"
              class="w-full"
              placeholder="+5511999998888"
            />
          </WithLabel>
          <WithLabel name="provider-email" :label="t('AI_BRAIN.STAFF.EMAIL')">
            <NextInput v-model="provider.email" type="email" class="w-full" />
          </WithLabel>
          <div class="flex items-center justify-between">
            <span class="text-sm text-n-slate-12">
              {{ t('AI_BRAIN.STAFF.BOOKABLE') }}
            </span>
            <Switch v-model="provider.bookable" />
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm text-n-slate-12">
              {{ t('AI_BRAIN.STAFF.RESPONDER') }}
            </span>
            <Switch v-model="provider.responder" />
          </div>
        </div>
      </Dialog>
    </template>
  </SettingsLayout>
</template>
