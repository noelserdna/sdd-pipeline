# Customer Needs — template and capture rules

`requirements/CUSTOMER-NEEDS.md` holds what the customer asked for, in their own words, before anyone turns it into requirements. Requirements are rewritten many times (EARS, splits, audits); the verbatim quote is the fixed point every requirement, demo and acceptance decision is checked against.

## Template

```markdown
# Customer Needs

> **Project:** {project name}
> **Captured by:** {who ran the elicitation, and how: interview, workshop, email thread…}
> **Last updated:** {YYYY-MM-DD}

### N-001: {short title in the customer's vocabulary}
- **Quote:** "{verbatim words of the customer}"
- **Who:** {name, role}
- **When:** {YYYY-MM-DD}
- **Status:** captured | confirmed | out-of-scope (decision: {what was decided, by whom, date})
```

## Rules

- **IDs** `N-NNN`, unique, never renumbered or reused (requirements, FASE demos and acceptance reports cite them).
- **Quote verbatim.** Copy the customer's sentence, including hedges ("it would be nice…"). Do not fix grammar or translate; a paraphrase already contains your interpretation. If the need came from a document, quote the document and put its reference in **Who**.
- **One need per block**, but do not split a sentence the customer said as one thought; requirements do the splitting.
- **Status flow:** `captured` when written down → `confirmed` after the customer hears it read back and agrees → optionally `out-of-scope` with the decision recorded in the parenthesis. An out-of-scope need is kept, never deleted: it documents what was consciously left out.
- **Coverage invariant** (checked mechanically by `sdd-jev.mjs needs --mechanical`): every need that is not out-of-scope is cited by at least one active requirement's `Needs:` line.

## Read-back (before writing any requirement)

Read the needs back with `AskUserQuestion`, one question per need and at most 4 questions per call. Each question shows the ID, title and quote, with options such as:

| Option | Effect |
|---|---|
| Yes, that is what I need | `Status: confirmed` |
| Not quite (customer rewords) | replace the quote with the new words, keep the ID, then confirm |
| Not for now | `Status: out-of-scope (decision: …)` with the customer's reason and the date |

Record the person who answered in **Who** if it differs from the original speaker. When running as a subagent there is no customer to ask: leave the needs `captured` and report that the read-back is pending.
