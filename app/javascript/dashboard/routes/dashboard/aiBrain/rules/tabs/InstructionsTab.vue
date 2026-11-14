<script setup>
import { useI18n } from 'vue-i18n';
import SectionLayout from '../../../settings/account/components/SectionLayout.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import StringListEditor from 'dashboard/components-next/aiBrain/StringListEditor.vue';
import WorkingHoursEditor from '../WorkingHoursEditor.vue';

// The business rules object the Rules page loads and saves.
const rules = defineModel({ type: Object, required: true });
const { t } = useI18n();
</script>

<template>
  <div class="flex flex-col gap-6 w-full">
    <SectionLayout :title="t('AI_BRAIN.GLOBAL_INSTRUCTIONS')" class="!pt-0">
      <div class="grid gap-4">
        <WithLabel
          name="global-instructions"
          :label="t('AI_BRAIN.GLOBAL_INSTRUCTIONS')"
        >
          <TextArea
            v-model="rules.globalInstructions"
            :max-length="4000"
            rows="5"
            class="w-full"
          />
        </WithLabel>
        <StringListEditor
          v-model="rules.companyRules"
          :label="t('AI_BRAIN.COMPANY_RULES')"
        />
        <StringListEditor
          v-model="rules.prohibitedBehaviors"
          :label="t('AI_BRAIN.PROHIBITED')"
        />
      </div>
    </SectionLayout>

    <SectionLayout :title="t('AI_BRAIN.WORKING_HOURS')" with-border>
      <WorkingHoursEditor v-model="rules.workingHours" />
    </SectionLayout>
  </div>
</template>
