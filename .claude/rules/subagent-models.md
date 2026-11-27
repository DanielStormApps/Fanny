# Subagent Models

When spawning subagents (`Agent` calls or workflow `agent()` calls), pick each one's model by what that stage does:

* **Main model (Opus)** - leave `model` unset. Orchestration, adjudication, and the final call. Treat every subagent finding as a claim to check, not a fact.
* **Sonnet (`model: 'sonnet'`)** - workers that need judgment: review finders, adversarial verifiers, translation, and native-language QA.
* **Haiku (`model: 'haiku'`)** - cheap mechanical stages where the inputs nearly decide the output: inventories and file listings, grep sweeps, format, parity, and existence checks, field extraction, and summarizing a known file.

Never use Haiku for verify or judge stages, or for output that gets applied without the main model reading it. Name the tiers that ran in the reply.
