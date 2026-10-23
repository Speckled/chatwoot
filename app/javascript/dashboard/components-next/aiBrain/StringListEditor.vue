<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

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
    <label class="font-medium">{{ label }}</label>
    <div v-for="(item, index) in modelValue" :key="index" class="flex gap-2">
      <input
        :value="item"
        class="flex-1 rounded border p-2"
        @input="change(index, $event.target.value)"
      />
      <button type="button" class="text-n-ruby-9" @click="remove(index)">
        {{ t('AI_BRAIN.REMOVE') }}
      </button>
    </div>
    <div class="flex gap-2">
      <input
        v-model="draft"
        class="flex-1 rounded border p-2"
        @keydown.enter.prevent="add"
      />
      <button type="button" class="rounded border px-3" @click="add">
        {{ t('AI_BRAIN.ADD') }}
      </button>
    </div>
  </div>
</template>
