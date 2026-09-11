# Groq realtime transcription decision — 2026-09-11

## Decision

**Do not implement Groq live transcription in Phase 8.** Keep Groq's existing
REST batch service as the only Groq path and use it as the fallback disposition
for Groq-backed sessions.

## Evidence checked

- Groq speech-to-text documentation:
  <https://console.groq.com/docs/speech-to-text>
- Groq realtime documentation entry point:
  <https://console.groq.com/docs/realtime>
- Groq pricing:
  <https://groq.com/pricing/>

The available speech-to-text contract documents file-upload transcription, not
a GA audio-in/audio-out transcription stream with interim transcript events.
The realtime documentation entry point does not provide the required stable
transcription message schema, interim-result semantics, or a documented
speech-to-text authentication contract that can be safely implemented here.
The automated documentation check was also unable to retrieve the protected
console pages reliably, so no endpoint or query parameters were inferred.

## Criteria

| Criterion | Result |
| --- | --- |
| Documented GA realtime transcription endpoint | Not established |
| Audio input format/message protocol | Not established for STT |
| Interim results stable enough for agreement | Not established |
| Existing Groq API key compatibility | Batch only |
| Streaming cost | Not established from a streaming STT contract |

A `gsk_…` key continues to work with the existing
`GroqTranscriptionService` batch endpoint. No realtime URL, event schema, or
live toggle is added, avoiding an unreachable or billable half-implementation.

## Revisit conditions

Re-evaluate when Groq publishes a stable speech-transcription realtime contract
that specifies audio framing, interim/final events, authentication, rate and
cost semantics, and cancellation behavior. At that point it can implement the
existing `CloudStreamingSession` protocol with the same reconnect and usage
meter rules as Deepgram.
