# One-Time Setup: Install Agent Skills

This guide covers how to install the Hy book API skills for different coding agents.

## gemini-cli

Symlink (recommended for local development): keep the skill in your book's repository but use it globally via the CLI:

```
mkdir -p ~/.gemini/skills/hylang-hy-dev
cp source_code_for_examples/AGENT_SKILLS_README.md ~/.gemini/skills/hylang-hy-dev/SKILL.md
pushd ~/.gemini/skills/
gemini skills link
popd
```

Verify it is installed:

```
gemini skills list
```

## Claude Code

Claude Code uses **CLAUDE.md** files for project-level context. To give Claude access to the Hy book APIs:

1. Copy or symlink the skill reference into your project root:

```bash
cp source_code_for_examples/AGENT_SKILLS_README.md /path/to/your/project/CLAUDE.md
```

Or, if you want to keep it alongside other instructions, append it:

```bash
cat source_code_for_examples/AGENT_SKILLS_README.md >> /path/to/your/project/CLAUDE.md
```

2. Alternatively, create a `.claude/` directory and place the file there:

```bash
mkdir -p /path/to/your/project/.claude
cp source_code_for_examples/AGENT_SKILLS_README.md /path/to/your/project/.claude/hy-book-apis.md
```

Claude Code will automatically read `CLAUDE.md` and any markdown files in `.claude/` at the start of each session.

## Hermes Agent

Hermes Agent by Nous Research stores reusable skills in `~/.hermes/skills/`. Copy the API reference there:

```bash
mkdir ~/.hermes/skills/hylang-hy-dev
cp source_code_for_examples/AGENT_SKILLS_README.md  ~/.hermes/skills/hylang-hy-dev/SKILL.md
```

Hermes will automatically discover files in its `skills/` directory and use them as context when generating code. Verify with:

```
hermes tools
```

## Google Antigravity

In each project directory:

Place the **source_code_for_examples/hy-book-apis/** folder inside a **.gemini/skills/** directory at the root of the project you have open in Antigravity.
