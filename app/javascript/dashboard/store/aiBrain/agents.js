import { defineStore } from 'pinia';
import agentsAPI from 'dashboard/api/aiBrain/agents';

export const useAiBrainAgentsStore = defineStore('aiBrainAgents', {
  state: () => ({
    agents: [],
    options: null,
    accountId: null,
    uiFlags: { fetching: false, saving: false },
  }),
  actions: {
    async fetch(accountId) {
      this.uiFlags.fetching = true;
      try {
        const { data } = await agentsAPI.get();
        this.accountId = accountId;
        this.agents = data;
        return data;
      } finally {
        this.uiFlags.fetching = false;
      }
    },
    async fetchOptions() {
      const { data } = await agentsAPI.getOptions();
      this.options = data;
      return data;
    },
    clear() {
      this.agents = [];
      this.options = null;
      this.accountId = null;
    },
  },
});
