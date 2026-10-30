import { frontendURL } from '../../../helper/URLHelper';
import SettingsWrapper from '../settings/SettingsWrapper.vue';
import Overview from './overview/Index.vue';
import Rules from './rules/Index.vue';
import Services from './services/Index.vue';

const meta = { permissions: ['administrator'] };
const route = (path, name, component) => ({
  path: frontendURL(`accounts/:accountId/ai-brain/${path}`),
  component: SettingsWrapper,
  props: { keepAlive: false },
  children: [
    {
      path: '',
      name,
      component,
      meta,
    },
  ],
});

export default [
  route('overview', 'ai_brain_overview', Overview),
  route('rules', 'ai_brain_rules', Rules),
  route('services', 'ai_brain_services', Services),
];
