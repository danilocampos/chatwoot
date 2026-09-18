import { mount } from '@vue/test-utils';
import FunnelEditor from '../FunnelEditor.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

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
    const remove = wrapper
      .findAll('button')
      .find(button => button.text() === 'KANBAN.FUNNELS.REMOVE');
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
});
