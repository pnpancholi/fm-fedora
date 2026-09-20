# {{PROJECT_NAME}} — Project Context

> **Inspired by:** [Omakub](https://github.com/basecamp/omakub) (Ubuntu) and [Omarchy](https://github.com/basecamp/omarchy) (Arch). Different direction, same spirit. MIT-licensed.

## Stack
- {{OS_DISTRO}} ({{OS_VERSION}})
- {{COMPOSER}} ({{COMPOSER_SOURCE}})
- {{TERMINAL}} ({{TERMINAL_SOURCE}})
- {{BAR}} ({{BAR_SOURCE}})
- {{SHELL_LANG}} {{SHELL_VERSION}}+ modules, zero deps

## Structure
```
{{ENTRY_SCRIPT}} → {{MAIN_INSTALLER}} → {{MODULES_DIR}}/{{FIRST_MODULE}}, {{MODULES_DIR}}/{{SECOND_MODULE}}...
{{HELPERS_FILE}} — logging + banner
```

## Current State
- {{CURRENT_MODULE_1}}: {{CURRENT_MODULE_1_DESC}}
- Planned: {{PLANNED_MODULES}}

## Philosophy
{{PILLAR_1}} • {{PILLAR_2}} • {{PILLAR_3}}

## Key Decisions (see DECISIONS.md)
| ADR | Topic | Decision |
|-----|-------|----------|
| {{ADR_1_NUM}} | {{ADR_1_TOPIC}} | {{ADR_1_SUMMARY}} |
| {{ADR_2_NUM}} | {{ADR_2_TOPIC}} | {{ADR_2_SUMMARY}} |
| {{ADR_3_NUM}} | {{ADR_3_TOPIC}} | {{ADR_3_SUMMARY}} |

## Extension Points
- Add modules: `{{MODULES_DIR}}/NN-name.sh`
- Config: `{{CONFIG_DIR}}/` (reserved)
- CLI tools: `{{BIN_DIR}}/` (reserved)

## Requirements
- {{REQ_1}}
- {{REQ_2}}
- {{REQ_3}}

## Quick Start
```bash
{{QUICK_START_CMD}}
```