# Privacy check of the synthetic corpus

Shared word runs: 10 words. Cosine threshold per response type: the 99% quantile of real responses' cosine to their nearest OTHER real response (e5). Responses with < 5 words: information only.

| response type | synthetic | real | exact (long) | exact (short) | shared word runs | cosine threshold | cosine > threshold (long) | cosine > threshold (short) | max cosine |
|---|---|---|---|---|---|---|---|---|---|
| apeq_text | 960 | 971 | 0 | 0 | 0 | 0.966 | 5 | 5 | 0.995 |
| (2 synthetic responses not in the synthetic run, not checked by cosine) ||||||||||
| gcmq_events | 605 | 604 | 0 | 1 | 0 | 0.953 | 16 | 3 | 0.987 |
| gcmq_health | 605 | 605 | 0 | 2 | 0 | 0.957 | 46 | 3 | 0.982 |
| ptsd_acute | 243 | 243 | 0 | 0 | 0 | 0.942 | 1 | 0 | 0.948 |
| ptsd_post | 238 | 235 | 0 | 0 | 0 | 0.948 | 0 | 0 | 0.947 |
| ptsd_treat | 233 | 231 | 0 | 5 | 0 | 0.936 | 0 | 3 | 0.944 |

**68 synthetic response(s) flagged for rewriting** (see synthetic/privacy_flagged.csv; synthetic text only).

## Review of the flagged responses

`synthetic/privacy_flagged.csv` is not published: the check was run by the
authors on the original data, and the flags are only meaningful next to the
real responses. Every flagged synthetic response was read side by side with
its most similar real response. None reproduces, paraphrases or is assembled
from a real response. A cosine above the threshold occurs for short responses
on the same everyday topic (e.g. feeling calmer, no lasting effect), which
differ in wording and detail. Two responses where the resemblance was closer
were rewritten before the final run; the table above is from the final
corpus. The "exact (short)" matches are responses of fewer than 5 words (e.g.
"none"), which carry no information about any participant.
