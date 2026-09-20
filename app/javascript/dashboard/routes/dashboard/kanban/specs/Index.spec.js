import { flushPromises, shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import KanbanAPI from 'dashboard/api/kanban';
import KanbanFunnelsAPI from 'dashboard/api/kanbanFunnels';
import KanbanBoard from 'dashboard/components/kanban/KanbanBoard.vue';
import FunnelEditor from 'dashboard/components/kanban/FunnelEditor.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Index from '../Index.vue';

vi.mock('dashboard/api/kanban', () => ({
  default: { getConversations: vi.fn(), moveConversation: vi.fn() },
}));
vi.mock('dashboard/api/kanbanFunnels', () => ({
  default: { get: vi.fn(), create: vi.fn(), update: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

describe('Kanban funnels', () => {
  const funnel = { id: 7, name: 'Sales', stages: [{ id: 'new', name: 'New' }] };
  const board = { kanban_data: {}, stats: { total: 0 }, meta: {} };
  let store;

  beforeEach(() => {
    store = createStore({
      getters: {
        getCurrentRole: () => 'administrator',
        'inboxes/getInboxes': () => [],
      },
      actions: { 'inboxes/get': vi.fn() },
    });
    KanbanFunnelsAPI.get.mockResolvedValue({ data: [funnel] });
    KanbanAPI.getConversations.mockResolvedValue({ data: board });
    KanbanAPI.moveConversation.mockResolvedValue({});
  });

  it('switches columns and scopes moves to the selected funnel', async () => {
    const wrapper = shallowMount(Index, { global: { plugins: [store] } });
    await flushPromises();
    wrapper.findComponent(Select).vm.$emit('update:modelValue', '7');
    await flushPromises();
    expect(KanbanAPI.getConversations).toHaveBeenLastCalledWith(
      expect.objectContaining({ funnel_id: '7' })
    );
    expect(wrapper.findComponent(KanbanBoard).props('columns')).toEqual([
      { id: 'new', title: 'New', dotClass: 'bg-n-blue-9' },
    ]);
    wrapper.findComponent(KanbanBoard).vm.$emit('moveCard', {
      conversationId: 42,
      targetStatus: 'new',
    });
    await flushPromises();
    expect(KanbanAPI.moveConversation).toHaveBeenCalledWith(42, 'new', '7');
  });

  it('transfers a conversation from the default board to a custom funnel', async () => {
    const wrapper = shallowMount(Index, { global: { plugins: [store] } });
    await flushPromises();
    wrapper.findComponent(KanbanBoard).vm.$emit('transferCard', {
      id: 42,
      kanban_status: 'novo_lead',
      contact: { name: 'Customer' },
    });
    await flushPromises();
    wrapper.findAllComponents(Select)[1].vm.$emit('update:modelValue', '7');
    await flushPromises();
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(KanbanAPI.moveConversation).toHaveBeenCalledWith(42, 'new', '7');
    expect(wrapper.find('form').exists()).toBe(false);
  });

  it('opens an administrator editor and selects the newly saved funnel', async () => {
    KanbanFunnelsAPI.create.mockResolvedValue({ data: { ...funnel, id: 8 } });
    const wrapper = shallowMount(Index, { global: { plugins: [store] } });
    await flushPromises();
    // Refresh is the first button; new funnel is the second.
    wrapper.findAllComponents({ name: 'Button' })[1].vm.$emit('click');
    await flushPromises();
    wrapper.findComponent(FunnelEditor).vm.$emit('save', {
      name: funnel.name,
      stages: funnel.stages,
    });
    await flushPromises();
    expect(KanbanFunnelsAPI.create).toHaveBeenCalledWith({
      funnel: { name: funnel.name, stages: funnel.stages },
    });
    expect(wrapper.findComponent(Select).props('modelValue')).toBe('8');
    expect(wrapper.findComponent(FunnelEditor).exists()).toBe(false);
  });

  it('does not let a stale response replace the currently selected funnel', async () => {
    let resolveDefault;
    KanbanAPI.getConversations.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          resolveDefault = resolve;
        })
    );
    const wrapper = shallowMount(Index, { global: { plugins: [store] } });
    await flushPromises();
    wrapper.findComponent(Select).vm.$emit('update:modelValue', '7');
    await flushPromises();
    resolveDefault({
      data: { ...board, kanban_data: { novo_lead: [{ id: 42 }] } },
    });
    await flushPromises();
    expect(
      wrapper.findComponent(KanbanBoard).props('conversationsByStatus')
    ).toEqual({});
  });

  it('lets agents select funnels without exposing configuration controls', async () => {
    const agentStore = createStore({
      getters: {
        getCurrentRole: () => 'agent',
        'inboxes/getInboxes': () => [],
      },
      actions: { 'inboxes/get': vi.fn() },
    });
    const wrapper = shallowMount(Index, { global: { plugins: [agentStore] } });
    await flushPromises();
    wrapper.findComponent(Select).vm.$emit('update:modelValue', '7');
    await flushPromises();
    expect(wrapper.findAllComponents({ name: 'Button' })).toHaveLength(1);
    expect(wrapper.findComponent(FunnelEditor).exists()).toBe(false);
  });
});
