# YYYY-MM · One-line title that states the finding, not the symptom

**Status:** open / closed / monitoring
**Impact:** hosts, users, duration
**Time to root cause:** wall clock, and how much of it was wasted

## Summary

Three to five sentences. What broke, from the outside. What the cause turned
out to be. What fixed it. No commands in this section.

## Timeline

Relative times are fine. Precise times belong in the appendix.

| t | event |
|---|---|
| T-2d | last known good deploy |
| T+0 | first alert |
| T+6m | first wrong hypothesis |

## What it looked like

The evidence as it presented itself, including the parts that pointed the wrong
way. This section is why the write-up is worth reading.

## How it was found

The command or observation that closed the loop. One or two, not ten.

## Root cause

The mechanism, not the blame. If there were two decisions that were each
reasonable and only wrong together, say so — that is usually the shape.

## Fix

Short term, then long term. Mark which one is actually deployed.

## What I would do differently

Honest list. "Look at the timer first", "I restarted before collecting",
"the health check was lying". This is the part future-me reads.

## Appendix

Full command output, redacted. Logs, `ss` output, `lsof` output, timeline CSV.
