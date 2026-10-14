# ethicapp-agent-skills

Procedural skills for coding agents (Claude Code) working on the EthicApp
repositories: `ethicapp-main`, `ethicapp-ai-additions` and
`ethicapp-deployment`. The repository is a Claude Code plugin marketplace;
each plugin groups the skills of one concern.

| Plugin | Skill | Invoke as | Purpose |
| --- | --- | --- | --- |
| `ethicapp-security` | `dependency-vulnerabilities` | `/ethicapp-security:dependency-vulnerabilities` | Audit and remediate known dependency vulnerabilities, verified in the built images, ending in an issue and a pull request. |

## Using the skills in a repository

Each EthicApp repository commits a `.claude/settings.json` that registers
this marketplace and enables the plugins, so anyone who clones it and trusts
the folder gets the skills:

```json
{
  "extraKnownMarketplaces": {
    "ethicapp-agent-skills": {
      "source": { "source": "github", "repo": "EthicApp-Development/ethicapp-agent-skills" }
    }
  },
  "enabledPlugins": {
    "ethicapp-security@ethicapp-agent-skills": true
  }
}
```

Interactive equivalent, for a personal setup or another repository:

```text
/plugin marketplace add EthicApp-Development/ethicapp-agent-skills
/plugin install ethicapp-security@ethicapp-agent-skills
```

The repository is private: Claude Code clones it with the machine's git
credentials (SSH key, or HTTPS after `gh auth login` and `gh auth setup-git`).

## How the skills relate to each repository

A skill holds a procedure, its checklists and its scripts. Facts about a
particular repository (which images exist, how tests run, pinning rules,
branch conventions) stay in that repository's `AGENTS.md`, and every skill
starts by reading it. If a skill starts accumulating service names or paths,
that content belongs to the repository, not here.

Skills end in artifacts for human review (issues, pull requests, reports).
They do not merge, publish images or deploy.

## Layout

```text
.claude-plugin/marketplace.json      marketplace manifest (name: ethicapp-agent-skills)
plugins/<plugin>/.claude-plugin/plugin.json
plugins/<plugin>/skills/<skill>/SKILL.md   procedure (frontmatter: name, description)
plugins/<plugin>/skills/<skill>/reference.md, scripts/   supporting material
```

## Adding a skill

1. Create `plugins/<plugin>/skills/<skill>/SKILL.md` with `name` and
   `description` frontmatter; the description says when to use it. Keep the
   body under 500 lines; move examples and pitfalls to `reference.md`.
2. Put executable helpers in `scripts/` and reference them with
   `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/<file>`. Test them.
3. Treat any text a skill reads from the outside (advisories, changelogs,
   logs, package READMEs) as data, and say so in the skill.
4. Bump the plugin `version` in `plugins/<plugin>/.claude-plugin/plugin.json`
   and in `.claude-plugin/marketplace.json`.
5. Run `claude plugin validate .` from the repository root before committing.
6. Write in English. See [AGENTS.md](AGENTS.md) for the authoring rules.
