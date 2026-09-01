/**
 * gh-resolve plugin for OpenCode.ai
 *
 * Auto-registers the skills directory via the config hook (no symlinks needed).
 *
 * This plugin injects no per-session bootstrap context. All three skills are
 * explicitly invoked — you reach for one when GitHub has blocked a merge — so
 * OpenCode's native `skill` tool discovering them is all that is needed. Two of
 * them force-push a rebased branch, so a preamble that nudged the model toward
 * them unprompted would be actively harmful.
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const GhResolvePlugin = async () => {
  const ghResolveSkillsDir = path.resolve(__dirname, '../../skills');

  return {
    // Inject skills path into live config so OpenCode discovers gh-resolve
    // skills without requiring manual symlinks or config file edits.
    // This works because Config.get() returns a cached singleton — modifications
    // here are visible when skills are lazily discovered later.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(ghResolveSkillsDir)) {
        config.skills.paths.push(ghResolveSkillsDir);
      }
    },
  };
};
