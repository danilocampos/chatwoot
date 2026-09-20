<script setup>
import KanbanColumn from './KanbanColumn.vue';

defineProps({
  columns: { type: Array, required: true },
  conversationsByStatus: { type: Object, required: true },
});

const emit = defineEmits(['moveCard', 'exportColumn', 'transferCard']);
</script>

<template>
  <div class="flex-1 min-h-0 overflow-x-auto">
    <div class="flex gap-4 px-6 pt-4 pb-6 h-full min-w-max">
      <KanbanColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :conversations="conversationsByStatus[column.id] || []"
        @move-card="emit('moveCard', $event)"
        @export-column="emit('exportColumn', $event)"
        @transfer-card="emit('transferCard', $event)"
      />
    </div>
  </div>
</template>
