import ApiClient from './ApiClient';

class KanbanFunnelsAPI extends ApiClient {
  constructor() {
    super('kanban_funnels', { accountScoped: true });
  }
}

export default new KanbanFunnelsAPI();
