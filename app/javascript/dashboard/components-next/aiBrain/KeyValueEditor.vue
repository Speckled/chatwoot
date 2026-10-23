<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

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
    <label class="font-medium">{{ t('AI_BRAIN.TOOL_PARAMETERS') }}</label>
    <div v-for="(item, name) in modelValue" :key="name" class="flex gap-2">
      <span class="w-1/3 truncate">{{ name }}</span>
      <input
        :value="item"
        class="flex-1 rounded border p-2"
        @input="change(name, $event.target.value)"
      />
      <button type="button" @click="remove(name)">
        {{ t('AI_BRAIN.REMOVE') }}
      </button>
    </div>
    <div class="flex gap-2">
      <input
        v-model="key"
        class="w-1/3 rounded border p-2"
        :placeholder="t('AI_BRAIN.KEY')"
      />
      <input
        v-model="value"
        class="flex-1 rounded border p-2"
        :placeholder="t('AI_BRAIN.VALUE')"
      />
      <button type="button" @click="add">{{ t('AI_BRAIN.ADD') }}</button>
    </div>
  </div>
</template>
