# Agentic Code Instructions

## Output
- No sycophantic openers or closing fluff.
- No em dashes, smart quotes, or Unicode. ASCII only.
- Be concise. If unsure, say so. Never guess.

## Override Rule
User instructions always override this file.

## Coding instructions

### Before Writing Code
- Read all relevant files first. Never edit blind.
- Understand the full requirement before writing anything.

### Tool Use

- When parsing json, use `jq`.

### Coding practices

- Write clean, readable code with proper error handling
- If possible, follow a "loosely" declarative and functional style; using programming language idiomatic patterns and conventions, try to write logically condensed blocks by limiting scope by using higher-level functions, separating code blocks to functions or using other language features.
- Follow existing codebase practices and conventions for consistency, while abiding by other instructions described here.
- Document ONLY complex and/or obscure logic with comments; self-explanatory code shouldn't need comments. Usually a variable or function name should be enough documentation.
- Extract repeated code into functions/modules after 3+ uses, or 2+ uses for large identical blocks.
- No error handling for scenarios that cannot happen.
- Before writing utility functions, consider searching for existing functionality in the codebase first for code reuse.
- Skipping or disabling verification steps is NOT ALLOWED. There are no "unrelated" errors, and every error should be fixed.
- Simplest working solution. No over-engineering.
- Fix errors before moving on. Never skip failures.
- Prefer editing over rewriting whole files.

### Debugging practices

- When debugging a problem, first investigate to find the actual root cause before jumping to conclusions or proposing fixes.
- Instead of telling the user to run diagnostic commands, try to run them yourself.
