<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import WhatsappProvidersAPI from 'dashboard/api/whatsappProviders';
import InboxesAPI from 'dashboard/api/inboxes';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({ inboxId: { type: Number, required: true } });
const state = ref({});
const busy = ref(false);
const failed = ref(false);
const credentials = ref({});
const tested = ref(null);
let timer;
const qr = computed(() => {
  const value = state.value.qr_data_url;
  return /^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(value || '')
    ? value
    : null;
});
const refresh = async () => {
  try {
    const response = await WhatsappProvidersAPI.show(props.inboxId);
    state.value = response.data;
    failed.value = false;
  } catch {
    failed.value = true;
  }
};
const connect = async () => {
  busy.value = true;
  try {
    await WhatsappProvidersAPI.connect(props.inboxId);
    await refresh();
  } catch {
    failed.value = true;
  } finally {
    busy.value = false;
  }
};
const save = async () => {
  busy.value = true;
  try {
    await InboxesAPI.update(props.inboxId, {
      channel: {
        provider_config: { ...state.value.config, ...credentials.value },
      },
    });
    credentials.value = {};
    await refresh();
  } catch {
    failed.value = true;
  } finally {
    busy.value = false;
  }
};
const testConnection = async () => {
  busy.value = true;
  try {
    await WhatsappProvidersAPI.testConnection(props.inboxId);
    tested.value = true;
  } catch {
    tested.value = false;
  } finally {
    busy.value = false;
  }
};
onMounted(() => {
  refresh();
  timer = setInterval(refresh, 5000);
});
onUnmounted(() => clearInterval(timer));
</script>

<template>
  <section class="space-y-4 p-4 border border-n-weak rounded-lg">
    <form v-if="state.fields?.length" class="space-y-4" @submit.prevent="save">
      <p>{{ $t('WHATSAPP_PROVIDERS.keep_secret') }}</p>
      <label v-for="field in state.fields" :key="field">
        {{ $t(`WHATSAPP_PROVIDERS.${field}`) }}
        <input
          v-model="credentials[field]"
          :type="field === 'instance_id' ? 'text' : 'password'"
          :placeholder="
            field === 'instance_id' ? state.config?.instance_id : '••••••••'
          "
          autocomplete="new-password"
        />
      </label>
      <Button
        type="submit"
        :label="$t('WHATSAPP_PROVIDERS.save')"
        :is-loading="busy"
      />
    </form>
    <h2 class="text-lg font-medium">{{ $t('WHATSAPP_PROVIDERS.state') }}</h2>
    <Button
      :label="$t('WHATSAPP_PROVIDERS.test')"
      :is-loading="busy"
      @click="testConnection"
    />
    <p v-if="tested !== null" role="status">
      {{
        tested
          ? $t('WHATSAPP_PROVIDERS.connected')
          : $t('WHATSAPP_PROVIDERS.connection_failed')
      }}
    </p>
    <p role="status">
      {{ state.connection || $t('WHATSAPP_PROVIDERS.disabled') }}
    </p>
    <p v-if="failed || state.error" role="alert">
      {{ $t('WHATSAPP_PROVIDERS.connection_failed') }}
    </p>
    <img
      v-if="qr"
      :src="qr"
      :alt="$t('WHATSAPP_PROVIDERS.qr')"
      class="w-64 max-w-full"
    />
    <Button
      :label="$t('WHATSAPP_PROVIDERS.connect')"
      :is-loading="busy"
      @click="connect"
    />
  </section>
</template>
