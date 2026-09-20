<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  filters: { type: Object, required: true },
  inboxes: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:filters', 'apply']);
const { t } = useI18n();

const updateFilter = (key, value) => {
  emit('update:filters', { ...props.filters, [key]: value });
};

const temperatureOptions = computed(() => [
  { value: '', label: t('KANBAN.FILTERS.ALL_TEMPERATURES') },
  { value: 'quente', label: t('KANBAN.TEMPERATURE.QUENTE') },
  { value: 'morno', label: t('KANBAN.TEMPERATURE.MORNO') },
  { value: 'frio', label: t('KANBAN.TEMPERATURE.FRIO') },
]);
const scoreOptions = computed(() => [
  { value: '', label: t('KANBAN.FILTERS.ALL_SCORES') },
  { value: 'alto', label: t('KANBAN.FILTERS.SCORE_HIGH') },
  { value: 'medio', label: t('KANBAN.FILTERS.SCORE_MEDIUM') },
  { value: 'baixo', label: t('KANBAN.FILTERS.SCORE_LOW') },
]);
const inboxOptions = computed(() => [
  { value: '', label: t('KANBAN.FILTERS.ALL_INBOXES') },
  ...props.inboxes.map(inbox => ({ value: inbox.id, label: inbox.name })),
]);
const hasFilters = computed(() => Object.values(props.filters).some(Boolean));

const clearFilters = () => {
  emit('update:filters', {
    search: '',
    temperatura: '',
    score: '',
    inbox_id: '',
  });
  emit('apply');
};
</script>

<template>
  <form
    class="flex flex-wrap items-center gap-2 py-4 mx-6 border-b border-n-weak"
    @submit.prevent="emit('apply')"
  >
    <Input
      :model-value="filters.search"
      type="search"
      class="w-full sm:w-64"
      custom-input-class="ltr:!pl-8 rtl:!pr-8"
      size="sm"
      :placeholder="t('KANBAN.FILTERS.SEARCH')"
      @update:model-value="updateFilter('search', $event)"
    >
      <template #prefix>
        <Icon
          icon="i-lucide-search"
          class="absolute -translate-y-1/2 size-4 top-1/2 text-n-slate-10 ltr:left-2.5 rtl:right-2.5"
        />
      </template>
    </Input>
    <Select
      :model-value="filters.temperatura"
      :options="temperatureOptions"
      :aria-label="t('KANBAN.FILTERS.TEMPERATURE')"
      class="w-full sm:w-auto [&>select]:w-full [&>select]:h-8 [&>select]:!py-1"
      @update:model-value="updateFilter('temperatura', $event)"
    />
    <Select
      :model-value="filters.score"
      :options="scoreOptions"
      :aria-label="t('KANBAN.FILTERS.SCORE')"
      class="w-full sm:w-auto [&>select]:w-full [&>select]:h-8 [&>select]:!py-1"
      @update:model-value="updateFilter('score', $event)"
    />
    <Select
      :model-value="filters.inbox_id"
      :options="inboxOptions"
      :aria-label="t('KANBAN.FILTERS.INBOX')"
      class="w-full sm:w-auto [&>select]:w-full [&>select]:h-8 [&>select]:!py-1"
      @update:model-value="updateFilter('inbox_id', $event)"
    />
    <Button
      :label="t('KANBAN.FILTERS.APPLY')"
      icon="i-lucide-list-filter"
      size="sm"
      type="submit"
    />
    <Button
      v-if="hasFilters"
      :label="t('KANBAN.FILTERS.CLEAR')"
      icon="i-lucide-x"
      color="slate"
      size="sm"
      type="button"
      variant="ghost"
      @click="clearFilters"
    />
  </form>
</template>
