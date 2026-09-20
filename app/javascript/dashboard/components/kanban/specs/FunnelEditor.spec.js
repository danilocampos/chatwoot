import { mount } from '@vue/test-utils';
import FunnelEditor from '../FunnelEditor.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: {
    props: ['cancelButtonLabel'],
    emits: ['confirm', 'close'],
    methods: { open: vi.fn() },
    template:
      '<form @submit.prevent="$emit(\'confirm\')"><slot /><button type="button" @click="$emit(\'close\')">{{ cancelButtonLabel }}</button></form>',
  },
}));

describe('FunnelEditor', () => {
  const funnel = {
    name: 'Sales',
    stages: [
      { id: 'new', name: 'New' },
      { id: 'won', name: 'Won' },
    ],
  };

  it('renames and reorders stages while preserving their identity and original data until save', async () => {
    const wrapper = mount(FunnelEditor, { props: { funnel } });
    await wrapper.findAll('input')[1].setValue(' Contacted ');
    await wrapper
      .findAll('[aria-label="KANBAN.FUNNELS.UP"]')[1]
      .trigger('click');
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('save')[0][0]).toEqual({
      name: 'Sales',
      stages: [funnel.stages[1], { id: 'new', name: 'Contacted' }],
    });
    expect(funnel.stages[0].name).toBe('New');
  });

  it('prevents removing the last stage and prevents duplicate submissions while saving', async () => {
    const wrapper = mount(FunnelEditor, {
      props: {
        funnel: { name: 'Sales', stages: [funnel.stages[0]] },
        saving: true,
      },
    });
    expect(wrapper.find('fieldset').attributes('disabled')).toBeDefined();
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('save')).toBeUndefined();
    await wrapper.setProps({ saving: false });
    const remove = wrapper.find('[aria-label="KANBAN.FUNNELS.REMOVE"]');
    expect(remove.attributes('disabled')).toBeDefined();
  });

  it('does not emit a save when cancelled', async () => {
    const wrapper = mount(FunnelEditor, { props: { funnel } });
    await wrapper.findAll('input')[0].setValue('Changed');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'KANBAN.FUNNELS.CANCEL')
      .trigger('click');
    expect(wrapper.emitted('cancel')).toHaveLength(1);
    expect(wrapper.emitted('save')).toBeUndefined();
    expect(funnel.name).toBe('Sales');
  });

  it('shows validation for whitespace-only names and preserves the draft on server failure', async () => {
    const wrapper = mount(FunnelEditor, { props: { funnel } });
    await wrapper.findAll('input')[0].setValue('   ');
    await wrapper.findAll('input')[1].setValue('   ');
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('save')).toBeUndefined();
    expect(wrapper.text()).toContain('KANBAN.FUNNELS.REQUIRED');
    await wrapper.findAll('input')[0].setValue('Sales updated');
    await wrapper.findAll('input')[1].setValue('Contacted');
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('save')).toHaveLength(1);
    await wrapper.setProps({ error: 'Unable to save' });
    expect(wrapper.find('[role="alert"]').text()).toBe('Unable to save');
    expect(wrapper.findAll('input')[0].element.value).toBe('Sales updated');
  });

  it('allows adding and removing stages and limits the funnel to twenty stages', async () => {
    const wrapper = mount(FunnelEditor, {
      props: {
        funnel: {
          name: 'Sales',
          stages: Array.from({ length: 19 }, (_, i) => ({
            id: String(i),
            name: String(i),
          })),
        },
      },
    });
    const add = wrapper
      .findAll('button')
      .find(button => button.text() === 'KANBAN.FUNNELS.ADD_STAGE');
    await add.trigger('click');
    expect(wrapper.findAll('input')).toHaveLength(21);
    expect(add.attributes('disabled')).toBeDefined();
    await wrapper
      .findAll('[aria-label="KANBAN.FUNNELS.REMOVE"]')[19]
      .trigger('click');
    expect(wrapper.findAll('input')).toHaveLength(20);
    expect(add.attributes('disabled')).toBeUndefined();
  });
});
