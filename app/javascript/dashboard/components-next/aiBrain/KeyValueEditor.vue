<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const key = ref('');
const value = ref('');
const add = () => {
  if (!key.value.trim()) return;
  emit('update:modelValue', {
    ...props.modelValue,
    [key.value.trim()]: value.value,
  });
  key.value = '';
  value.value = '';
};
const change = (name, newValue) =>
  emit('update:modelValue', { ...props.modelValue, [name]: newValue });
const remove = name => {
  const updated = { ...props.modelValue };
  delete updated[name];
  emit('update:modelValue', updated);
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <label class="text-sm font-medium leading-6 text-n-slate-12">{{
      t('AI_BRAIN.TOOL_PARAMETERS')
    }}</label>
    <div
      v-for="(item, name) in modelValue"
      :key="name"
      class="flex items-center gap-2"
    >
      <span class="w-1/3 truncate text-sm text-n-slate-12 font-medium">{{
        name
      }}</span>
      <NextInput
        :model-value="item"
        class="flex-1"
        @input="change(name, $event.target.value)"
      />
      <Button
        type="button"
        variant="ghost"
        color="ruby"
        size="sm"
        icon="i-woot-bin"
        :label="t('AI_BRAIN.REMOVE')"
        @click="remove(name)"
      />
    </div>
    <div class="flex items-center gap-2">
      <NextInput v-model="key" class="w-1/3" :placeholder="t('AI_BRAIN.KEY')" />
      <NextInput
        v-model="value"
        class="flex-1"
        :placeholder="t('AI_BRAIN.VALUE')"
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
