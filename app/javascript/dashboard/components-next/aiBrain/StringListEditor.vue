<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  label: { type: String, required: true },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const draft = ref('');
const add = () => {
  if (!draft.value.trim()) return;
  emit('update:modelValue', [...props.modelValue, draft.value.trim()]);
  draft.value = '';
};
const change = (index, value) =>
  emit(
    'update:modelValue',
    props.modelValue.map((item, i) => (i === index ? value : item))
  );
const remove = index =>
  emit(
    'update:modelValue',
    props.modelValue.filter((_, i) => i !== index)
  );
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium leading-6 text-n-slate-12">{{
      label
    }}</label>
    <div
      v-for="(item, index) in modelValue"
      :key="index"
      class="flex items-center gap-2"
    >
      <NextInput
        :model-value="item"
        class="flex-1"
        @input="change(index, $event.target.value)"
      />
      <Button
        type="button"
        variant="ghost"
        color="ruby"
        size="sm"
        icon="i-woot-bin"
        :label="t('AI_BRAIN.REMOVE')"
        @click="remove(index)"
      />
    </div>
    <div class="flex items-center gap-2">
      <NextInput
        v-model="draft"
        class="flex-1"
        :placeholder="label"
        @enter="add"
      />
      <Button
        type="button"
        variant="faded"
        color="slate"
        size="md"
        :label="t('AI_BRAIN.ADD')"
        @click="add"
      />
    </div>
  </div>
</template>
