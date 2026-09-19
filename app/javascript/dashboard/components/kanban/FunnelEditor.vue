<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  funnel: { type: Object, default: null },
  saving: { type: Boolean, default: false },
});
const emit = defineEmits(['save', 'cancel']);
const { t } = useI18n();
const name = ref(props.funnel?.name || '');
const stages = ref(
  props.funnel?.stages.map(stage => ({ ...stage })) || [
    { id: crypto.randomUUID(), name: '' },
  ]
);
const reorder = (index, offset) => {
  const [stage] = stages.value.splice(index, 1);
  stages.value.splice(index + offset, 0, stage);
};
const save = () => {
  if (props.saving) return;
  emit('save', {
    name: name.value.trim(),
    stages: stages.value.map(stage => ({ ...stage, name: stage.name.trim() })),
  });
};
const addStage = () => {
  stages.value.push({ id: crypto.randomUUID(), name: '' });
};
</script>

<template>
  <form class="p-4 border-b border-n-weak bg-n-solid-2" @submit.prevent="save">
    <fieldset :disabled="saving" class="space-y-3 max-w-2xl">
      <legend class="mb-3 font-medium">
        {{ funnel ? t('KANBAN.FUNNELS.EDIT') : t('KANBAN.FUNNELS.NEW') }}
      </legend>
      <label class="block">
        <span class="text-sm">{{ t('KANBAN.FUNNELS.NAME') }}</span>
        <input v-model="name" required maxlength="80" class="w-full" />
      </label>
      <p class="text-xs text-n-slate-11">{{ t('KANBAN.FUNNELS.HINT') }}</p>
      <div
        v-for="(stage, index) in stages"
        :key="stage.id"
        class="flex gap-2 items-center"
      >
        <label class="flex-1">
          <span class="sr-only">{{
            t('KANBAN.FUNNELS.STAGE', { number: index + 1 })
          }}</span>
          <input
            v-model="stage.name"
            required
            maxlength="80"
            :placeholder="t('KANBAN.FUNNELS.STAGE', { number: index + 1 })"
            class="w-full !mb-0"
          />
        </label>
        <button
          type="button"
          :disabled="index === 0"
          :aria-label="t('KANBAN.FUNNELS.UP')"
          class="p-2 disabled:opacity-30"
          @click="reorder(index, -1)"
        >
          <Icon icon="i-lucide-arrow-up" class="size-4" />
        </button>
        <button
          type="button"
          :disabled="index === stages.length - 1"
          :aria-label="t('KANBAN.FUNNELS.DOWN')"
          class="p-2 disabled:opacity-30"
          @click="reorder(index, 1)"
        >
          <Icon icon="i-lucide-arrow-down" class="size-4" />
        </button>
        <button
          type="button"
          :disabled="stages.length === 1"
          class="text-sm text-n-ruby-11 disabled:opacity-30"
          @click="stages.splice(index, 1)"
        >
          {{ t('KANBAN.FUNNELS.REMOVE') }}
        </button>
      </div>
      <div class="flex gap-3 items-center">
        <button
          type="button"
          :disabled="stages.length >= 20"
          class="text-sm text-n-blue-11 disabled:opacity-30"
          @click="addStage"
        >
          {{ t('KANBAN.FUNNELS.ADD_STAGE') }}
        </button>
        <button type="submit" class="px-3 py-2 rounded bg-n-brand text-white">
          {{ t('KANBAN.FUNNELS.SAVE') }}
        </button>
        <button type="button" class="text-sm" @click="emit('cancel')">
          {{ t('KANBAN.FUNNELS.CANCEL') }}
        </button>
      </div>
    </fieldset>
  </form>
</template>
