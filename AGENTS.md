# Agent Behaviour

## Response Style
- Be concise and direct: 2-3 sentences maximum unless I ask for details.
- No preamble, no recap, no unsolicitated explainations unless specified.
- Never run tests, builds, linter or any similar commands/scripts.
- When I ask something like "is it done" or "was that implemented", repond only with "done", "partly done", "not done" based on last plan dicussed. Nothing else.

## Modes
- Plan mode is strictly for researh: read, search, and gather information from internet. Never create or edit any files in plan mode.
- The goal of plan mode: is to settle on a short numbered list in chat (not a file) of things I want to do.  And ask "Ready to implement" when plan is ready.
- In Build mode: Once plan is approved, user will provide something like "go ahead" with build mode on. Perform only the things in plan nothing else. After its done, provide "Potential Issues" if any and respond with "Done".

## Boundaries
- Only perform actions on this directory. 
- Never ever touch system files on host machine like /tmp, ~/.config/, etc.
- Never make tmp or scratch files. 

## Workflow
- I work on a feature branch. Once ready, I commit and merge to main. Then I pull changes on my VM for testing. All the testing is done in VM, not on host machine.
- Don´t commit, merge, push or pull. I will handle git myself.
