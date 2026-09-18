<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import KanbanAPI from 'dashboard/api/kanban';
import KanbanFunnelsAPI from 'dashboard/api/kanbanFunnels';
import FunnelEditor from 'dashboard/components/kanban/FunnelEditor.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import KanbanBoard from 'dashboard/components/kanban/KanbanBoard.vue';
import KanbanFilters from 'dashboard/components/kanban/KanbanFilters.vue';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const store = useStore();

const conversationsByStatus = ref({});
const stats = ref({ total: 0, by_temperatura: {} });
const meta = ref({ truncated: false });
const filters = ref({ search: '', temperatura: '', score: '', inbox_id: '' });
const isLoading = ref(false);
const movingConversationId = ref(null);
const funnels = ref([]);
const funnelId = ref('');
const editorOpen = ref(false);
const editingFunnel = ref(null);
const savingFunnel = ref(false);
const transferring = ref(null);
const destinationId = ref('');
const destinationStage = ref('');
const isAdmin = computed(
  () => store.getters.getCurrentRole === 'administrator'
);
const selectedFunnel = computed(() =>
  funnels.value.find(funnel => String(funnel.id) === String(funnelId.value))
);
let loadSequence = 0;

const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const defaultColumns = computed(() => [
  {
    id: 'novo_lead',
    title: t('KANBAN.STATUS.NOVO_LEAD'),
    dotClass: 'bg-n-blue-9',
  },
  {
    id: 'aquecimento',
    title: t('KANBAN.STATUS.AQUECIMENTO'),
    dotClass: 'bg-n-amber-9',
  },
  {
    id: 'qualificado',
    title: t('KANBAN.STATUS.QUALIFICADO'),
    dotClass: 'bg-n-teal-9',
  },
  {
    id: 'convertido',
    title: t('KANBAN.STATUS.CONVERTIDO'),
    dotClass: 'bg-n-iris-9',
  },
  { id: 'perdido', title: t('KANBAN.STATUS.PERDIDO'), dotClass: 'bg-n-ruby-9' },
]);
const columns = computed(() =>
  selectedFunnel.value
    ? selectedFunnel.value.stages.map(stage => ({
        id: stage.id,
        title: stage.name,
        dotClass: 'bg-n-blue-9',
      }))
    : defaultColumns.value
);
const destinationStages = computed(() => {
  const funnel = funnels.value.find(
    item => String(item.id) === String(destinationId.value)
  );
  return funnel
    ? funnel.stages
    : defaultColumns.value.map(column => ({
        id: column.id,
        name: column.title,
      }));
});

const loadConversations = async () => {
  loadSequence += 1;
  const sequence = loadSequence;
  isLoading.value = true;
  try {
    const { data } = await KanbanAPI.getConversations({
      ...filters.value,
      funnel_id: funnelId.value,
    });
    if (sequence !== loadSequence) return;
    conversationsByStatus.value = data.kanban_data;
    stats.value = data.stats;
    meta.value = data.meta;
  } catch {
    if (sequence === loadSequence) useAlert(t('KANBAN.API.ERROR.FETCH'));
  } finally {
    if (sequence === loadSequence) isLoading.value = false;
  }
};

const changeFunnel = () => {
  conversationsByStatus.value = {};
  stats.value = { total: 0, by_temperatura: {} };
  editorOpen.value = false;
  transferring.value = null;
  loadConversations();
};

const openEditor = funnel => {
  editingFunnel.value = funnel || null;
  editorOpen.value = true;
};

const saveFunnel = async funnel => {
  savingFunnel.value = true;
  try {
    const { data } = editingFunnel.value
      ? await KanbanFunnelsAPI.update(editingFunnel.value.id, { funnel })
      : await KanbanFunnelsAPI.create({ funnel });
    const index = funnels.value.findIndex(item => item.id === data.id);
    if (index < 0) funnels.value.push(data);
    else funnels.value.splice(index, 1, data);
    funnelId.value = String(data.id);
    changeFunnel();
  } catch {
    useAlert(t('KANBAN.FUNNELS.ERROR'));
  } finally {
    savingFunnel.value = false;
  }
};

const startTransfer = conversation => {
  transferring.value = conversation;
  destinationId.value = funnelId.value;
  destinationStage.value = conversation.kanban_status;
};

const transferConversation = async () => {
  if (movingConversationId.value) return;
  movingConversationId.value = transferring.value.id;
  try {
    await KanbanAPI.moveConversation(
      transferring.value.id,
      destinationStage.value,
      destinationId.value
    );
    transferring.value = null;
    await loadConversations();
    useAlert(t('KANBAN.API.SUCCESS.MOVE'));
  } catch {
    useAlert(t('KANBAN.API.ERROR.MOVE'));
  } finally {
    movingConversationId.value = null;
  }
};

const moveConversation = async ({ conversationId, targetStatus }) => {
  if (movingConversationId.value) return;

  movingConversationId.value = conversationId;
  try {
    await KanbanAPI.moveConversation(
      conversationId,
      targetStatus,
      funnelId.value
    );
    await loadConversations();
    useAlert(t('KANBAN.API.SUCCESS.MOVE'));
  } catch {
    useAlert(t('KANBAN.API.ERROR.MOVE'));
  } finally {
    movingConversationId.value = null;
  }
};

const csvCell = value => `"${String(value ?? '').replaceAll('"', '""')}"`;
const exportColumn = async status => {
  try {
    const { data } = await KanbanAPI.exportConversations({
      ...filters.value,
      funnel_id: funnelId.value,
      status,
    });
    if (!data.data.length) {
      useAlert(t('KANBAN.EXPORT.NO_DATA'));
      return;
    }

    const headers = Object.keys(data.data[0]);
    const rows = data.data.map(row =>
      headers.map(header => csvCell(row[header])).join(',')
    );
    const blob = new Blob(
      [`\uFEFF${[headers.join(','), ...rows].join('\n')}`],
      {
        type: 'text/csv;charset=utf-8',
      }
    );
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `kanban-${status}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    useAlert(t('KANBAN.EXPORT.SUCCESS'));
  } catch {
    useAlert(t('KANBAN.EXPORT.ERROR'));
  }
};

onMounted(async () => {
  store.dispatch('inboxes/get');
  try {
    const { data } = await KanbanFunnelsAPI.get();
    funnels.value = data;
  } catch {
    useAlert(t('KANBAN.FUNNELS.FETCH_ERROR'));
  }
  loadConversations();
});
</script>

<template>
  <main class="flex flex-col w-full h-full min-h-0 bg-n-background">
    <header
      class="flex justify-between items-center px-5 py-4 border-b bg-n-solid-1 border-n-weak"
    >
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('KANBAN.TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-10">
          {{ t('KANBAN.CONVERSATION_COUNT', { count: stats.total || 0 }) }}
        </p>
      </div>
      <Button
        outline
        slate
        md
        :is-loading="isLoading"
        @click="loadConversations"
      >
        <Icon icon="i-lucide-refresh-cw" class="mr-2 size-4" />
        {{ t('KANBAN.REFRESH') }}
      </Button>
    </header>

    <div
      class="flex flex-wrap gap-3 items-center px-5 py-3 border-b border-n-weak"
    >
      <label class="flex gap-2 items-center text-sm">
        {{ t('KANBAN.FUNNELS.LABEL') }}
        <select
          v-model="funnelId"
          :disabled="savingFunnel || !!movingConversationId"
          class="!mb-0"
          @change="changeFunnel"
        >
          <option value="">{{ t('KANBAN.FUNNELS.DEFAULT') }}</option>
          <option
            v-for="funnel in funnels"
            :key="funnel.id"
            :value="String(funnel.id)"
          >
            {{ funnel.name }}
          </option>
        </select>
      </label>
      <Button
        v-if="isAdmin"
        :disabled="savingFunnel"
        sm
        outline
        @click="openEditor(null)"
      >
        {{ t('KANBAN.FUNNELS.NEW') }}
      </Button>
      <Button
        v-if="isAdmin && selectedFunnel"
        :disabled="savingFunnel"
        sm
        ghost
        @click="openEditor(selectedFunnel)"
      >
        {{ t('KANBAN.FUNNELS.EDIT') }}
      </Button>
    </div>
    <FunnelEditor
      v-if="editorOpen"
      :key="editingFunnel?.id || 'new'"
      :funnel="editingFunnel"
      :saving="savingFunnel"
      @save="saveFunnel"
      @cancel="editorOpen = false"
    />
    <form
      v-if="transferring"
      class="flex flex-wrap gap-3 items-center p-4 border-b border-n-weak"
      @submit.prevent="transferConversation"
    >
      <span class="text-sm">{{
        t('KANBAN.FUNNELS.MOVING', { name: transferring.contact.name })
      }}</span>
      <select
        v-model="destinationId"
        :aria-label="t('KANBAN.FUNNELS.LABEL')"
        :disabled="!!movingConversationId"
        class="!mb-0"
        @change="destinationStage = destinationStages[0].id"
      >
        <option value="">{{ t('KANBAN.FUNNELS.DEFAULT') }}</option>
        <option
          v-for="funnel in funnels"
          :key="funnel.id"
          :value="String(funnel.id)"
        >
          {{ funnel.name }}
        </option>
      </select>
      <select
        v-model="destinationStage"
        :aria-label="t('KANBAN.FUNNELS.DESTINATION_STAGE')"
        :disabled="!!movingConversationId"
        class="!mb-0"
      >
        <option
          v-for="stage in destinationStages"
          :key="stage.id"
          :value="stage.id"
        >
          {{ stage.name }}
        </option>
      </select>
      <button
        type="submit"
        :disabled="!!movingConversationId"
        class="px-3 py-2 rounded bg-n-brand text-white"
      >
        {{ t('KANBAN.FUNNELS.CONFIRM_MOVE') }}
      </button>
      <button
        type="button"
        :disabled="!!movingConversationId"
        class="text-sm"
        @click="transferring = null"
      >
        {{ t('KANBAN.FUNNELS.CANCEL') }}
      </button>
    </form>

    <KanbanFilters
      v-model:filters="filters"
      :inboxes="inboxes"
      @apply="loadConversations"
    />

    <div
      v-if="meta.truncated"
      class="px-4 py-2 text-sm border-b bg-n-amber-3 text-n-amber-11 border-n-amber-6"
    >
      {{ t('KANBAN.LIMIT_NOTICE', { count: meta.limit }) }}
    </div>

    <div
      v-if="isLoading && !stats.total"
      class="flex flex-1 justify-center items-center"
    >
      <Spinner />
    </div>
    <KanbanBoard
      v-else
      :columns="columns"
      :conversations-by-status="conversationsByStatus"
      @move-card="moveConversation"
      @export-column="exportColumn"
      @transfer-card="startTransfer"
    />
  </main>
</template>
