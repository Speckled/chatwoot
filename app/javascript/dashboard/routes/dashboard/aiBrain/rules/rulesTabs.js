// The Rules page's sub-tabs, in order. The id is what the ?tab= query carries, so a link can open a tab directly.
export const RULES_TABS = [
  { id: 'configuration', labelKey: 'AI_BRAIN.TABS.CONFIGURATION' },
  { id: 'instructions', labelKey: 'AI_BRAIN.TABS.INSTRUCTIONS' },
  { id: 'knowledge', labelKey: 'AI_BRAIN.TABS.KNOWLEDGE' },
  { id: 'services', labelKey: 'AI_BRAIN.TABS.SERVICES' },
];

// The tabs that edit the business rules, which share one Save.
export const RULES_FORM_TABS = ['configuration', 'instructions'];

// Unknown or missing ids open the first tab.
export const tabIndex = id =>
  Math.max(
    0,
    RULES_TABS.findIndex(tab => tab.id === id)
  );
