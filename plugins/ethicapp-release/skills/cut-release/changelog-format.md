# CHANGELOG entry format

Readers are maintainers and the people who operate EthicApp deployments.
They want to know what a release brings and what deploying it requires.
Write in English, plainly, and state only what you checked.

## Example

```markdown
## [v2026.11.05] - 2026-11-05

Teacher home in the Actividades design (epic #1093).

Partial release: only the `ethicapp` image.

### Added

- The teacher home lists "Actividades en curso" (five rows) and "Terminadas
  recientemente" (three rows) with the Actividades table, row actions, notices
  and empty page (#1121, epic #1093).

### Changed

- The launcher is one row of tiles, and the home no longer scrolls sideways
  (#1121).

### Deployment

- Migrations: none.
- Environment contract: unchanged.
```

## Rules

1. **Heading.** `## [<tag>] - <YYYY-MM-DD>`, with the date the images were
   published. The tag is exactly the image tag.
2. **Headline.** The first paragraph is one line that names the release's
   main content and ends in a full stop. Name epics as `epic #N`. The same
   headline goes in the tag message and in the GitHub Release title.
3. **Second paragraph.** Add it only when one of these applies:
   - `Partial release: only the <image> image(s).`
   - `Hotfix superseding <tag>.`
   - the branch, for a release not built from `main`.
4. **Subsections.** Use these, in this order, and only when they have
   content: `### Added`, `### Changed`, `### Fixed`, `### Removed`,
   `### Security`, `### Deployment`.
5. **`### Deployment`.** It is always present:
   - `Migrations: V41, V42 and V43 (V43 drops users.rut).` or
     `Migrations: none.`
   - `Environment contract: adds X; removes Y.` or
     `Environment contract: unchanged.` Name new secrets.
   - Manual steps and ordering constraints: preflight queries, "deploy
     together with ethicapp-ai-additions <tag>", backfills.
6. **Bullets.** Each bullet is one change, stated in the present tense. End
   it with references in parentheses:
   - issues and pull requests as `#N`;
   - epics as `epic #N`;
   - cross-repository references as `ethicapp-main#N` or
     `ethicapp-ai-additions#N`.

   Prefer the issue a pull request closes over the pull request itself.
7. **Grouping.** Group small pull requests by epic or theme. An entry has 2
   to 12 bullets; never list every pull request. Leave out housekeeping:
   typo fixes, example bumps, merges of `main` into a branch.
8. **Style.**
   - Write the entry for operators.
   - No em dashes and no bold or italics inside bullets.
   - No "notably", "importantly" or similar adverbs.
   - Product texts that are Spanish in the UI stay in Spanish, in quotes.
9. **Link reference.** Each entry has a link reference line at the bottom of
   the file:

   ```markdown
   [v2026.11.05]: https://github.com/EthicApp-Development/ethicapp-main/releases/tag/v2026.11.05
   ```

   GitHub serves that URL for every tag, whether or not it has a GitHub
   Release.
