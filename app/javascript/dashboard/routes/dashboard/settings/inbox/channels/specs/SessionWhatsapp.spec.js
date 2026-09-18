import { flushPromises, mount } from '@vue/test-utils';
import SessionWhatsapp from '../SessionWhatsapp.vue';

const dispatch = vi.fn();
vi.mock('vuex', () => ({ useStore: () => ({ dispatch }) }));
vi.mock('vue-router', () => ({ useRouter: () => ({ replace: vi.fn() }) }));

describe('Session WhatsApp inbox form', () => {
  const mountForm = () =>
    mount(SessionWhatsapp, {
      props: {
        provider: {
          id: 'zapi',
          fields: ['instance_id', 'token', 'client_token'],
        },
      },
      global: {
        mocks: { $t: key => key },
        stubs: {
          Button: { template: '<button type="submit" />' },
          ProviderConnection: true,
        },
      },
    });

  it('masks secret inputs and submits to the ordinary inbox workflow', async () => {
    dispatch.mockResolvedValueOnce({ id: 42 });
    const wrapper = mountForm();
    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('Support');
    await inputs[1].setValue('+5511999999999');
    await inputs[2].setValue('instance');
    await inputs[3].setValue('secret');
    await inputs[4].setValue('client-secret');
    expect(inputs[3].attributes('type')).toBe('password');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(dispatch).toHaveBeenCalledWith(
      'inboxes/createChannel',
      expect.objectContaining({
        channel: expect.objectContaining({
          provider: 'zapi',
          provider_config: {
            instance_id: 'instance',
            token: 'secret',
            client_token: 'client-secret',
          },
        }),
      })
    );
    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.html()).not.toContain('client-secret');
  });

  it('shows a generic error without echoing the remote response', async () => {
    dispatch.mockRejectedValueOnce(new Error('private-token'));
    const wrapper = mountForm();
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(wrapper.find('[role="alert"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('private-token');
  });
});
