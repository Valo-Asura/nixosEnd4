# AI-Focused NixOS Workstation and Experimentation Workflow

Status: updated for the `x15xs` NixOS flake on `2026-05-06`.

## 1. Project Overview

This project is my attempt to turn a personal NixOS laptop into a practical AI workstation for daily experimentation, coding, and debugging. I am not treating it like a DevOps platform or trying to oversell it as production infrastructure. It is much closer to a fast feedback lab: break things, inspect behavior, fix the config, dry-build it, and repeat.

The system is built around:

- NixOS flakes for reproducible system state
- Hyprland as the main Wayland session
- i3 as an X11 fallback session
- Ollama for local LLM experiments
- AI coding agents and AI IDEs for real config/debugging tasks
- a modular Nix layout so system behavior is easier to change without turning the repo into one huge file

The main engineering work was not “setting up Linux” in a generic way. It was debugging workflow friction:

- fixing inconsistent Hyprland keybindings so launchers and session actions behave predictably
- fixing unreliable workspace switching by tightening gesture behavior instead of leaving swipe handling half-random
- stabilizing Hyprland startup and reducing quickshell-related session noise
- testing the i3 fallback session as a real backup path instead of leaving it unverified
- preparing Secure Boot in a modular folder so it is ready for future use without mixing it into unrelated boot logic
- keeping the config reproducible enough that I can dry-build changes before trusting them

The mindset here is simple: vibe coded, but validated properly. I let tools help, but I still read the config, inspect diffs, and confirm the system still evaluates cleanly.

## 2. Local LLM + RAG Exploration

### 2.1 Where local AI tool state usually lives on Linux

On Linux, most AI tools follow the normal XDG pattern:

- `~/.config/` for user config, editor settings, extension state, and app-specific databases
- `~/.local/share/` for persistent app data
- `~/.cache/` for disposable caches, model metadata, and temporary indexing artifacts
- `~/.local/state/` for mutable runtime-ish state that should survive restarts

On this machine, the AI editor family is mostly living under `~/.config/`:

- Cursor: `~/.config/Cursor/`
- Windsurf: `~/.config/Windsurf/`
- Kiro: `~/.config/Kiro/`
- Antigravity: `~/.config/Antigravity/`
- VS Code: `~/.config/Code/`

Inside those directories, the useful subpaths are usually:

- `User/settings.json` for editor settings
- `User/workspaceStorage/` for per-workspace state and indexing side effects
- `User/globalStorage/` for extension or agent state
- `User/History/` for command/file history
- `logs/` for debugging weird agent or extension behavior
- `CachedData/`, `Code Cache/`, `GPUCache/` for Electron/Chromium cache layers

For Ollama, the exact storage layout depends on how it is installed, but the usual places to inspect are:

- `~/.ollama/` for user-level keys and local client state
- `/var/lib/ollama/` or a service-managed data directory for pulled model blobs on system installs
- the Ollama service environment for host binding and port exposure

On this machine, `~/.ollama/` currently contains the local key material:

- `~/.ollama/id_ed25519`
- `~/.ollama/id_ed25519.pub`

For Continue.dev, I treat these as the first places to inspect:

- `~/.continue/`
- editor-side storage under `~/.config/Code/User/globalStorage/`
- Cursor/Windsurf equivalents if Continue is installed there instead of plain VS Code

The exact path can shift between app versions, so I do not assume one hardcoded location forever. I usually confirm by checking `User/globalStorage`, `workspaceStorage`, and `logs` first.

### 2.2 How editor agents and indexing usually behave

Cursor, Windsurf, Kiro, and similar Electron-based IDEs tend to follow the same pattern:

- they keep user settings in `User/settings.json`
- they build per-workspace indexes inside `User/workspaceStorage/`
- they write extension state to `User/globalStorage/`
- they keep logs under `logs/`
- they cache webview, GPU, and model-adjacent data under `Cache`, `CachedData`, and `GPUCache`

That matters for debugging because “the AI is acting weird” is often just:

- stale workspace indexing
- old extension state
- a broken path in `settings.json`
- an Electron cache issue
- a mismatch between the terminal Python and the editor Python

### 2.3 Exposing a local LLM server on the LAN

The easiest pattern is:

1. Run Ollama on the workstation.
2. Bind it to a LAN-reachable address instead of localhost.
3. Allow only the local subnet through the firewall.
4. Put a tiny API layer in front if I want prompt templates, retrieval, logging, or auth.

At a basic level, another device can talk to the workstation over HTTP if Ollama is listening on something like:

```text
0.0.0.0:11434
```

Then a laptop, phone, or another dev box on the same network can send requests to:

```text
http://<workstation-ip>:11434/api/generate
```

I usually prefer wrapping that with FastAPI so I can control:

- which model gets used
- what prompt format is allowed
- whether retrieval context gets injected
- whether requests are logged
- whether the endpoint stays LAN-only

### 2.4 Simple RAG flow

The RAG path I experiment with is intentionally small:

1. Split notes, docs, config files, or code into chunks.
2. Create embeddings for those chunks.
3. Store the embeddings in a vector database.
4. On a question, embed the query.
5. Retrieve the nearest chunks.
6. Build a grounded prompt from the retrieved context.
7. Send that prompt to the local model through Ollama.

### 2.5 Simple architecture diagram

```text
[Phone / Laptop / IDE]
          |
          v
    [FastAPI Wrapper]
          |
          +-------------------+
          |                   |
          v                   v
   [Vector DB / Chunks]   [Ollama API]
          |                   |
          +---------+---------+
                    |
                    v
             [Grounded Response]
```

### 2.6 Example FastAPI + Ollama workflow

The shape is roughly:

1. A client sends `POST /ask` with a user question.
2. FastAPI embeds the question and queries the vector store.
3. The top matching chunks are packed into a short context block.
4. FastAPI sends the final prompt to Ollama.
5. Ollama returns a response from the selected local model.
6. FastAPI sends the final answer back to the client.

Very small version:

```text
client -> FastAPI -> retrieve relevant chunks -> build prompt -> Ollama -> response
```

That is enough to test whether local retrieval actually improves answer quality before building anything fancier.

### 2.7 Security considerations for LAN exposure

If I expose a local LLM server beyond localhost, I keep the security model simple and boring:

- bind only to the local network, not the public internet
- restrict firewall rules to trusted devices or the home subnet
- put FastAPI or a reverse proxy in front if I want auth or rate limits
- do not expose raw filesystem access through the model endpoint
- be careful with retrieved data if the vector store contains private notes, tokens, or code
- keep logs in mind because prompt history can become sensitive data very quickly

For personal experiments, LAN-only plus a narrow firewall rule is usually enough.

## 3. AI IDE / Agent Testing Workflow

I tested these tools against the same kind of messy, real system work instead of toy prompts:

- Codex
- Cursor
- Windsurf
- Continue
- Kiro
- Antigravity
- free-tier chat and coding workflows when I wanted a cheap baseline

The test method was intentionally hands-on.

### 3.1 My validation loop

1. Pick a real system task.
   Example: broken Hyprland binds, unreliable workspace gestures, i3 fallback issues, Python path drift in IDEs, or Secure Boot cleanup.
2. Give the same task to different tools.
3. Watch how they inspect context.
   I care about whether they read the repo first or immediately hallucinate a fix.
4. Compare how they handle cross-file edits.
   NixOS config work is rarely one-file-only.
5. Check whether they understand the difference between declarative config and runtime state.
6. Dry-build or run targeted tests after every serious change.
7. Keep the parts that survive validation and throw away the rest.

### 3.2 What I compare between tools

- context gathering quality
- whether they understand Nix files without flattening everything into generic Linux advice
- how well they keep track of related files across `hosts/`, `modules/`, and `home/`
- whether they break session behavior while fixing one issue
- how noisy their edits are
- whether they recover well after a wrong first attempt
- how much manual cleanup I still need to do

### 3.3 What indexing behavior taught me

This part matters more than I expected.

Some IDE agents feel smart until the workspace index goes stale, the interpreter path drifts, or the extension storage gets weird. I ended up paying a lot more attention to:

- `workspaceStorage`
- `globalStorage`
- extension logs
- model/provider config files
- whether the tool re-reads the current repo after I change files outside the editor

That made the workflow more practical. Instead of saying “tool X is bad,” I started asking:

- is the index stale?
- is it reading the right Python?
- is it using the right project root?
- is its cached state fighting the declarative config?

### 3.4 How the vibe-coding part actually works

My workflow is not pure manual config and it is not blind AI automation either.

It is usually:

1. describe the problem in plain English
2. let an agent inspect the repo
3. accept a first draft or partial fix
4. read the diff carefully
5. adjust the bad assumptions
6. dry-build
7. test the actual session behavior

That is why I describe it as vibe coded but validated properly. The AI helps with speed, but the trust comes from reproducible config and checking the result.

### 3.5 Real tasks I used for comparison

- fixing broken launcher bindings in Hyprland
- making workspace gestures feel consistent again
- reducing quickshell startup noise
- making the i3 fallback session feel usable instead of abandoned
- fixing Python, `pip`, and `uv` path mismatches in AI editors
- checking how well tools reason about Nix modules versus runtime state

Those tasks were useful because they mix shell, editor setup, desktop behavior, and declarative config. That is where weak context handling usually shows up fast.

## 4. Resume Project Section

### Project Title

AI-Focused NixOS Workstation for Local LLM, Agent, and RAG Experimentation

### Resume-Ready Description

Built and maintained a modular NixOS workstation for local LLM experimentation, AI coding-agent evaluation, and Linux workflow debugging. Customized Hyprland and an i3 fallback session, fixed inconsistent keybindings and workspace gestures, stabilized quickshell behavior, and structured the system with reproducible flake-based configuration and modular Secure Boot preparation.

### Key Technologies Used

- NixOS
- Nix flakes
- Hyprland
- i3
- Quickshell
- Ollama
- FastAPI
- Python
- local vector database tooling
- AI IDEs and coding agents

### Key Learnings

- local AI workflow quality depends as much on editor state and indexing as on the model itself
- declarative configs make repeated AI-assisted debugging much safer
- desktop workflow issues are a good stress test for agent context handling
- small, validated local RAG setups are easier to reason about than overbuilt stacks
- reproducibility matters a lot when experimenting with multiple AI tools at once

## 5. LinkedIn Post

I have been building my NixOS laptop into a small AI-focused workstation and it has been a very good way to learn by actually breaking things.

The stack is pretty personal and practical: Hyprland as the main session, i3 as a fallback, Ollama for local LLMs, and a bunch of AI coding tools like Codex, Cursor, Windsurf, Continue, Kiro, and other free-tier workflows to compare how they behave on real tasks.

Most of the work was not “big architecture.” It was debugging annoying real problems:

- inconsistent keybindings
- mouse/workspace gesture issues in Hyprland
- quickshell startup noise
- editor Python/path drift
- making the i3 fallback session actually usable

I also started using the same machine to explore basic local RAG patterns: chunk docs, embed them, store them in a vector DB, retrieve the useful parts, and send the grounded prompt to a local model through Ollama.

What I like about this kind of project is that it feels honest. A lot of it is vibe coding, but I still have to validate everything with dry builds, config review, and actual behavior checks. That makes it a really good learning loop for backend + AI tooling work.

Still very much in the “intermediate builder” phase, but I am learning a lot about local inference, developer tooling, and how different agents handle messy real system tasks instead of clean demo prompts.
