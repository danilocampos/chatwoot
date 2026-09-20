<script setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  funnel: { type: Object, default: null },
  saving: { type: Boolean, default: false },
  error: { type: String, default: '' },
});
const emit = defineEmits(['save', 'cancel']);
const { t } = useI18n();
const MAX_STAGES = 20;
const dialogRef = ref(null);
const attempted = ref(false);
const name = ref(props.funnel?.name || '');
const stages = ref(
  props.funnel?.stages.map(stage => ({ ...stage })) || [
    { id: crypto.randomUUID(), name: '' },
  ]
);
const nameInvalid = computed(() => attempted.value && !name.value.trim());
const reorder = (index, offset) => {
  const [stage] = stages.value.splice(index, 1);
  stages.value.splice(index + offset, 0, stage);
};
const save = () => {
  if (props.saving) return;
  attempted.value = true;
  if (!name.value.trim() || stages.value.some(stage => !stage.name.trim())) {
    return;
  }
  emit('save', {
    name: name.value.trim(),
    stages: stages.value.map(stage => ({ ...stage, name: stage.name.trim() })),
  });
};
const close = async () => {
  if (props.saving) {
    await nextTick();
    dialogRef.value.open();
    return;
  }
  emit('cancel');
};
const addStage = async () => {
  const id = crypto.randomUUID();
  stages.value.push({ id, name: '' });
  await nextTick();
  document.getElementById(`kanban-stage-${id}`)?.focus();
};

onMounted(() => dialogRef.value.open());
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="xl"
    :title="funnel ? t('KANBAN.FUNNELS.EDIT') : t('KANBAN.FUNNELS.NEW')"
    :confirm-button-label="t('KANBAN.FUNNELS.SAVE')"
    :cancel-button-label="t('KANBAN.FUNNELS.CANCEL')"
    :is-loading="saving"
    @confirm="save"
    @close="close"
  >
    <fieldset :disabled="saving" class="min-w-0 space-y-6">
      <Input
        v-model="name"
        :label="t('KANBAN.FUNNELS.NAME')"
        :placeholder="t('KANBAN.FUNNELS.NAME_PLACEHOLDER')"
        :message="nameInvalid ? t('KANBAN.FUNNELS.REQUIRED') : ''"
        :message-type="nameInvalid ? 'error' : 'info'"
        :aria-invalid="nameInvalid"
        maxlength="80"
        autofocus
      />
      <section class="space-y-3">
        <div class="flex items-center justify-between gap-3">
          <h4 class="text-sm font-medium text-n-slate-12">
            {{ t('KANBAN.FUNNELS.STAGES') }}
          </h4>
          <span class="text-xs tabular-nums text-n-slate-10">
            {{
              t('KANBAN.FUNNELS.STAGE_COUNT', {
                count: stages.length,
                max: MAX_STAGES,
              })
            }}
          </span>
        </div>
        <div class="space-y-2">
          <div
            v-for="(stage, index) in stages"
            :key="stage.id"
            class="flex items-start gap-2"
          >
            <span
              class="flex items-center justify-center w-6 h-10 shrink-0 text-xs tabular-nums text-n-slate-10"
            >
              {{ index + 1 }}
            </span>
            <Input
              :id="`kanban-stage-${stage.id}`"
              v-model="stage.name"
              maxlength="80"
              :aria-label="t('KANBAN.FUNNELS.STAGE', { number: index + 1 })"
              :placeholder="t('KANBAN.FUNNELS.STAGE', { number: index + 1 })"
              :message="
                attempted && !stage.name.trim()
                  ? t('KANBAN.FUNNELS.REQUIRED')
                  : ''
              "
              :message-type="attempted && !stage.name.trim() ? 'error' : 'info'"
              class="flex-1"
            />
            <div class="flex items-center h-10 shrink-0">
              <Button
                :aria-label="t('KANBAN.FUNNELS.UP')"
                :title="t('KANBAN.FUNNELS.UP')"
                icon="i-lucide-arrow-up"
                color="slate"
                size="sm"
                type="button"
                variant="ghost"
                :disabled="index === 0"
                @click="reorder(index, -1)"
              />
              <Button
                :aria-label="t('KANBAN.FUNNELS.DOWN')"
                :title="t('KANBAN.FUNNELS.DOWN')"
                icon="i-lucide-arrow-down"
                color="slate"
                size="sm"
                type="button"
                variant="ghost"
                :disabled="index === stages.length - 1"
                @click="reorder(index, 1)"
              />
              <Button
                :aria-label="t('KANBAN.FUNNELS.REMOVE')"
                :title="t('KANBAN.FUNNELS.REMOVE')"
                icon="i-lucide-trash-2"
                color="slate"
                size="sm"
                type="button"
                variant="ghost"
                class="hover:!text-n-ruby-11"
                :disabled="stages.length === 1"
                @click="stages.splice(index, 1)"
              />
            </div>
          </div>
        </div>
        <Button
          :label="t('KANBAN.FUNNELS.ADD_STAGE')"
          icon="i-lucide-plus"
          color="slate"
          size="sm"
          type="button"
          variant="ghost"
          :disabled="stages.length >= MAX_STAGES"
          @click="addStage"
        />
        <p class="mb-0 text-xs leading-5 text-n-slate-11">
          {{ t('KANBAN.FUNNELS.HINT') }}
        </p>
      </section>
      <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
        {{ error }}
      </p>
    </fieldset>
  </Dialog>
</template>
