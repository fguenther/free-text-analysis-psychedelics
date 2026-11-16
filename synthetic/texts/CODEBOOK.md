# Codebook of the synthetic free-text corpus

All texts in `synthetic/texts/*.csv` are synthetic. Each response was written
whole by Claude for the public synthetic version of this project; none is
copied, paraphrased or assembled from a real participant response. The real
responses were only read to calibrate style (register, length, typos,
abbreviations, mix of German and English).

Every response is tagged with one score per theme of its response type:

| Score | Meaning |
|---|---|
| 0 | absent |
| 1 | mentioned in passing / implied |
| 2 | clearly present, one of the main points |
| 3 | dominant: the response is mostly about this |

Scores describe the text as written, not what the person may have meant. A
terse response ("Very intense, felt reborn") usually has one or two themes at
1–2. Themes are not mutually exclusive and not bipolar; e.g. *positive affect*
and *insight* can both be 3.

## Files and columns

`<dataset>_<group>_<NN>.csv`, UTF-8, comma-separated, every text in double
quotes (inner quotes doubled). Columns: `id, language, text, <theme scores>`.
`language` is `eng` or `ger`. Line breaks inside GCMQ and PTSD texts are
written as `<br>`, as in the raw survey exports (APEQ texts are single-line).

| Type | File stem | id | Rows |
|---|---|---|---|
| APEQ text | `apeq_text_NN` | `apeq_0001` … | 960 |
| GCMQ events | `gcmq_events_NN` | `gcmq_0001` … (same id = same person as in health) | 605 |
| GCMQ health | `gcmq_health_NN` | `gcmq_0001` … | 605 |
| PTSD acute | `ptsd_acute_NN` | `ptsd_001` … (same id = same person across acute/post/treat) | 243 |
| PTSD post | `ptsd_post_NN` | `ptsd_001` … | 243 (238 + 5 empty) |
| PTSD treat | `ptsd_treat_NN` | `ptsd_001` … | 243 (233 + 10 empty) |

Empty PTSD responses are empty strings with all theme scores 0. As in the real
data (10 participants left at least one response empty), the 5 participants
with an empty `post` response also left `treat` empty; 5 further participants
left only `treat` empty.

Intended signal (for the generator; mirrors the paper's qualitative results):
**bold** themes carry signal, *(+)* raises and *(−)* lowers the outcome. All
other themes are realistic content without planted effect (they may overlap
with other predictors, e.g. therapeutic motives).

---

## APEQ `text` — the psychedelic experience and its impact

Prompt: participants described one psychedelic experience, mostly in terms of
what it changed for them afterwards (the raw column is the free-text "impact"
answer), sometimes as a description of the trip itself.

| Column | Theme | Score high when … | Signal |
|---|---|---|---|
| `pos_affect` | **Positive affect / relief / life satisfaction** | happiness, joy, calm, relaxation, relief of depression/anxiety, feeling good, enjoying life, contentment, "feel reborn" | **WHO-5 (+)** |
| `insight` | **Insight / self-awareness / metacognition / evaluation** | becoming aware of own thoughts, patterns, mental states; judging oneself, one's relationships, job, society; "I realised…", reflecting on how one thinks. Not the opposite of `pos_affect`: a text can be calm and insightful at once. | **WHO-5 (−)**, AAQ-II (see below) |
| `acceptance` | Acceptance / letting go | accepting emotions, past, death, uncertainty; less avoidance and struggle; letting go of control; facing rather than suppressing | suggested AAQ-II carrier (more acceptance → larger decrease in inflexibility) |
| `challenging` | Challenging / fear / negative | fear, panic, bad trip, confusion, overwhelm during the experience, or negative after-effects (anxiety, relapse, "no benefit") | none |
| `mystical` | Unity / mystical / spiritual | oneness, ego dissolution, contact with something greater, spiritual meaning, timelessness, awe | none |
| `sensory` | Sensory / visual / fun | visuals, colours, music, bodily sensations, laughter, "just a nice trip" | none |
| `social` | Social / connection | relationships, empathy, love for others, partner, friends, family, feeling connected to people | none |
| `therapeutic` | Therapeutic intention / healing use | the experience was used or framed as treatment: depression, trauma, addiction, therapy setting, intention-setting, healing | none (overlaps with the therapeutic-motives predictor) |
| `setting` | Plain description of setting / substance / dose | substance names, dose, place, festival, nature, ceremony, who was there, timeline | none |

AAQ-II: the paper reports a text signal for AAQ-II change as well, without
qualitative examples. We suggest planting it through `acceptance` (and
weakly `pos_affect`); the generator decides the exact weights.

## GCMQ `events` — impact on handling stressful events

No planted effect; realistic mix only.

| Column | Theme | Score high when … |
|---|---|---|
| `calm_coping` | Calmer coping | more serenity, less stress reactivity, staying calm in crises, "gelassener" |
| `perspective` | Perspective / relativising | things seem smaller or temporary, bigger picture, problems lose weight, trust in life/universe |
| `acceptance` | Acceptance / facing | accepting what cannot be changed, facing instead of avoiding, letting feelings be |
| `self_insight` | Understanding own reactions | recognising own patterns, triggers, trauma, why one reacts as one does |
| `tools` | Concrete strategies | breathing, meditation, pausing before reacting, journaling, sport, therapy skills |
| `social` | Social handling | talking openly, asking for help, empathy with others in conflicts, relationships |
| `no_change` | No change / unsure | no change, no stressful events since, unsure whether caused by the experience |
| `negative` | Worse handling | more anxiety or sensitivity to stress, destabilisation, panic since the experience |

## GCMQ `health` — impact on mental health

Planted effect is very small (WEMWBS).

| Column | Theme | Score high when … | Signal |
|---|---|---|---|
| `euphoria_love` | **Euphoria / connectedness / love** | euphoria, love for self/others/world, feeling connected, warmth, bliss | **WEMWBS (+)** |
| `open_mind` | **Open-mindedness** | more open to new ideas, people, perspectives, curiosity, less judgemental | **WEMWBS (+)** |
| `appreciation` | **Appreciation of life** | gratitude, appreciating small things, joy of being alive, life feels worth living | **WEMWBS (+)** |
| `symptom_relief` | Symptom relief | depression, anxiety, addiction, PTSD symptoms reduced | none |
| `self_understanding` | Self-understanding | understanding own history, trauma, emotions, self-acceptance | none |
| `indifference` | **Indifference** | things matter less in a flat way, "it is what it is", don't care, detached, emotionally flat | **WEMWBS (−)** |
| `short_lived` | **Short-lived effects** | effects lasted only days/weeks, afterglow faded, back to old state | **WEMWBS (−)** |
| `no_impact` | **No impact** | no effect on mental health, "keine", "not really", only recreational | **WEMWBS (−)** |
| `negative` | Negative impact | anxiety, derealisation, worse mood, destabilisation after the experience | none |

## PTSD `acute` — the challenging experience during the acute effects

No planted effect (neither PCL-5 nor PTGI).

| Column | Theme | Score high when … |
|---|---|---|
| `fear_panic` | Fear / panic / terror | panic, dread, horror, paranoia, feeling of dying |
| `ego_dissolution` | Ego dissolution / death | ego death, losing the sense of self, dying and being reborn, nothingness |
| `loss_control` | Loss of control / reality | going insane, psychosis, time loops, not knowing what is real, can't stop it |
| `entities_visions` | Entities / visions / hell | demons, beings, hellish or cosmic visions, messages, archetypes |
| `physical` | Physical symptoms | nausea, vomiting, heart racing, paralysis, seizures, breathing, temperature |
| `setting` | Setting / substance / dose | festival, alone, ceremony, retreat, dose, mixing substances, unknown substance |
| `social_context` | Other people / aftermath | friends, sitters, strangers, police, hospital, abandonment, being judged |
| `resolution` | Resolution / meaning in the trip | surrender, acceptance, beauty, the trip turning, lessons during the experience |

## PTSD `post` — persistent symptoms afterwards

Strong planted effect on PCL-5. PTGI: no planted effect.

| Column | Theme | Score high when … | Signal |
|---|---|---|---|
| `anxiety_panic` | **Anxiety / panic** | panic attacks, generalised anxiety, health anxiety, fear of going crazy | **PCL-5 (+)** |
| `dpdr` | **Depersonalisation / derealisation** | unreality, detachment from body/self, world feels fake, dreamlike | **PCL-5 (+)** |
| `depression` | **Depression** | low mood, hopelessness, anhedonia, suicidal thoughts, exhaustion | **PCL-5 (+)** |
| `hppd_visual` | **HPPD / visual snow** | visual snow, afterimages, trails, breathing walls, tinnitus | **PCL-5 (+)** |
| `intrusive` | **Intrusive thoughts / flashbacks / nightmares** | flashbacks, intrusive memories, nightmares, triggers, avoidance of reminders | **PCL-5 (+)** |
| `other_symptoms` | **Other symptoms** | insomnia, existential dread, OCD-like loops, social withdrawal, concentration, physical symptoms | **PCL-5 (+)** |
| `no_difficulty` | **No persistent difficulties** | nothing lasting, symptoms gone after a few days, "none" | **PCL-5 (−)** |
| `self_insight` | **Insights about oneself** | the aftermath brought understanding of oneself, growth, lessons, perspective | **PCL-5 (−)** |

Suggested PCL-5 driver: the sum (or maximum) of the six symptom themes, minus
`no_difficulty` and `self_insight`.

## PTSD `treat` — attempts to address the symptoms

Moderate planted effect on PCL-5. PTGI: no planted effect.

| Column | Theme | Score high when … | Signal |
|---|---|---|---|
| `therapy` | Psychotherapy / psychiatry | therapist, psychiatrist, clinic, trauma therapy, EMDR | none (mention only) |
| `integration` | Integration / talking / reading | integration circles, talking to experienced people, forums, books, writing about it | none |
| `self_care` | Meditation / body / lifestyle | meditation, yoga, breathwork, sport, nature, sleep, diet, quitting drugs | none |
| `medication` | Medication | SSRIs, benzodiazepines, antipsychotics, other prescribed drugs | none |
| `time` | Time | it got better by itself with time, waiting it out | none |
| `psychedelics_again` | Psychedelics again | re-dosing, microdosing, ketamine, another ceremony to resolve it | none |
| `helped` | **Something helped / recovery** | degree to which the text says an attempt helped or that the person is doing well now | **PCL-5 (−)** |
| `still_struggling` | **Nothing helped / still struggling / harmed** | nothing helped, still suffering, attempts made it worse, dismissive doctors, hopelessness | **PCL-5 (+)** |
| `no_need` | No attempts needed | no symptoms to treat, didn't need anything, no attempts made | none |

`helped` and `still_struggling` can both be > 0 (e.g. "therapy helped a bit,
but the DP is still there").
