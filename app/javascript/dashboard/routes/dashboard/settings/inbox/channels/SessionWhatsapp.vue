<script setup>
import { ref } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import ProviderConnection from './ProviderConnection.vue';

const props = defineProps({ provider: { type: Object, required: true } });
const store = useStore();
const router = useRouter();
const name = ref('');
const phone = ref('');
const credentials = ref({});
const inboxId = ref(null);
const busy = ref(false);
const error = ref(false);
const create = async () => {
  busy.value = true;
  error.value = false;
  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: name.value.trim(),
      channel: {
        type: 'whatsapp',
        provider: props.provider.id,
        phone_number: phone.value,
        provider_config: credentials.value,
      },
    });
    credentials.value = {};
    inboxId.value = inbox.id;
  } catch {
    error.value = true;
  } finally {
    busy.value = false;
  }
};
const next = () =>
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: { page: 'new', inbox_id: inboxId.value },
  });
</script>

<template>
  <div class="space-y-4">
    <form v-if="!inboxId" class="space-y-4" @submit.prevent="create">
      <label>
        {{ $t('WHATSAPP_PROVIDERS.name') }}
        <input v-model="name" required type="text" />
      </label>
      <label>
        {{ $t('WHATSAPP_PROVIDERS.phone') }}
        <input
          v-model="phone"
          required
          type="tel"
          pattern="\+[1-9][0-9]{6,14}"
        />
      </label>
      <label v-for="field in provider.fields" :key="field">
        {{ $t(`WHATSAPP_PROVIDERS.${field}`) }}
        <input
          v-model="credentials[field]"
          required
          :type="field === 'instance_id' ? 'text' : 'password'"
          autocomplete="new-password"
        />
      </label>
      <p v-if="error" role="alert">
        {{ $t('WHATSAPP_PROVIDERS.invalid_configuration') }}
      </p>
      <Button
        type="submit"
        :label="$t('WHATSAPP_PROVIDERS.create')"
        :is-loading="busy"
      />
    </form>
    <template v-else>
      <ProviderConnection :inbox-id="inboxId" />
      <Button :label="$t('WHATSAPP_PROVIDERS.continue')" @click="next" />
    </template>
  </div>
</template>
