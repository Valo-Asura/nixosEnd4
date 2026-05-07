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

On Linux, local AI tooling usually follows the normal XDG layout:

- `~/.config/` for user config, editor settings, extension state, and app databases
- `~/.cache/` for disposable caches, embeddings caches, and temporary indexes
- `~/.local/share/` for app data that should persist
- `~/.local/state/` for mutable local state that should survive restarts but is not really config

For editor-based AI tools, the most common place to start is `~/.config/<AppName>/`.

On this workstation, that means:

- Cursor: `~/.config/Cursor/`
- Windsurf: `~/.config/Windsurf/`
- Kiro: `~/.config/Kiro/`
- Antigravity: `~/.config/Antigravity/`
- VS Code: `~/.config/Code/`

Inside those app folders, the paths that usually matter are:

- `User/settings.json` for editor and model settings
- `User/workspaceStorage/` for per-project state and indexing
- `User/globalStorage/` for extension-level state
- `User/History/` for prompt/file/command history depending on the app
- `logs/` for debugging agent errors
- `Cache`, `CachedData`, `Code Cache`, and `GPUCache` for Electron/Chromium cache layers

### 2.2 Ollama, Continue, and IDE-specific storage

For Ollama, I separate three things:

- local user state like keys under `~/.ollama/`
- server-managed model storage, commonly under `/usr/share/ollama/.ollama/models` on Linux service installs
- service configuration through environment variables such as `OLLAMA_HOST`

Important detail: Ollama itself is mainly a model server. Prompt history is often stored by the client or UI using Ollama, not by Ollama in one neat “chat history” file.

For Continue.dev, the first places I would inspect are:

- `~/.continue/config.yaml`
- `~/.continue/.env`
- `<project>/.continue/` for project-specific prompts, checks, or config fragments
- editor extension state under `~/.config/Code/User/globalStorage/` or the equivalent folder in Cursor/Windsurf

For Cursor, Windsurf, and Kiro, the practical pattern is similar:

- settings in `User/settings.json`
- indexing and per-project memory in `User/workspaceStorage/`
- extension state in `User/globalStorage/`
- logs in `logs/`

That is usually where “why is this AI tool acting strange?” gets solved:

- stale index
- broken workspace state
- bad model config
- wrong Python/interpreter path
- old cache or extension state

### 2.3 Exposing a local LLM server on the LAN

The simplest setup is:

1. Run Ollama on the workstation.
2. Change the bind address from localhost to a LAN address.
3. Open the firewall only for trusted devices on the local network.
4. Optionally put FastAPI in front of it instead of exposing raw Ollama directly.

Ollama listens on `127.0.0.1:11434` by default. A common way to expose it on the LAN is to set:

```text
OLLAMA_HOST=0.0.0.0:11434
```

Then another machine on the same network can send prompts to:

```text
http://<workstation-ip>:11434/api/generate
```

If I want a cleaner workflow, I usually place a small FastAPI wrapper in front of Ollama so I can decide:

- which model gets called
- what prompt shape is allowed
- whether retrieval context gets added
- whether request logging is enabled
- whether the endpoint should stay LAN-only

### 2.4 How another device can send prompts

Another laptop, tablet, or phone on the same LAN can send a normal HTTP request.

The flow is straightforward:

1. device sends a prompt to the workstation IP
2. FastAPI receives it
3. FastAPI forwards the final request to Ollama
4. Ollama returns the model output
5. FastAPI returns the result to the device

This can be as simple as a `curl` request, a tiny web UI, or a small mobile/desktop client.

### 2.5 How retrieval / RAG can work

The retrieval flow I use for experiments is intentionally simple:

1. Split notes, docs, config files, or code into chunks.
2. Create embeddings for those chunks.
3. Store the embeddings in a vector database.
4. On a question, embed the query.
5. Retrieve the nearest chunks.
6. Build a grounded prompt from the retrieved context.
7. Send that prompt to the local model through Ollama.

The important part is the separation:

- embeddings turn text into searchable vectors
- the vector DB stores and looks up those vectors
- retrieval picks relevant chunks
- the LLM writes the final answer using that retrieved context

### 2.6 Simple architecture diagram

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

### 2.7 Example FastAPI + Ollama workflow

The shape is usually:

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

That is enough to test whether retrieval actually improves answer quality without building a huge system first.

### 2.8 Security considerations for local network exposure

If I expose the local model outside localhost, I keep the setup simple:

- bind only to the local network, not the public internet
- restrict firewall rules to trusted devices or the home subnet
- put FastAPI or a reverse proxy in front if I want auth or rate limits
- do not expose raw filesystem access through the model endpoint
- be careful with retrieved data if the vector store contains private notes, tokens, or code
- remember that logs can become sensitive very quickly if prompts include code or private notes

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
