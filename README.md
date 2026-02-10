# mod_audio_fork

A FreeSWITCH module that attaches a media bug to a channel and streams L16 audio via WebSockets to a remote server. This module supports **bidirectional audio** — receiving audio back from the server for real-time playback to the caller, enabling full-fledged IVR, dialog, and voice-bot applications.

## Features

- **Bidirectional Audio** — Stream audio to a WebSocket server and receive audio back for real-time playback
- **Binary Audio Streaming** — Receive raw binary audio frames from the server (in addition to base64-encoded JSON)
- **Audio Markers** — Synchronize audio playback with named markers (`mark` / `clearMarks`)
- **Multiple Mix Types** — Mono (caller only), mixed (caller + callee), or stereo (separate channels)
- **Flexible Sample Rates** — 8000, 16000, 24000, 32000, 48000, 64000 Hz (any multiple of 8000)
- **Automatic Resampling** — Built-in Speex resampler for sample rate conversion
- **TLS Support** — Secure WebSocket connections (wss://)
- **SIMD Optimized** — AVX2/SSE2 vector math for audio processing
- **Graceful Shutdown** — Drain audio buffers before closing connections

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `MOD_AUDIO_FORK_SUBPROTOCOL_NAME` | WebSocket [sub-protocol](https://tools.ietf.org/html/rfc6455#section-1.9) name | `audio.drachtio.org` |
| `MOD_AUDIO_FORK_SERVICE_THREADS` | Number of libwebsocket service threads (1–5) | `1` |
| `MOD_AUDIO_FORK_BUFFER_SECS` | Audio buffer size in seconds (1–5) | `2` |

## Channel Variables

| Variable | Description |
|---|---|
| `MOD_AUDIO_BASIC_AUTH_USERNAME` | HTTP Basic Auth username for WebSocket connection |
| `MOD_AUDIO_BASIC_AUTH_PASSWORD` | HTTP Basic Auth password for WebSocket connection |
| `MOD_AUDIO_FORK_ALLOW_SELFSIGNED` | Allow self-signed TLS certificates (`true`/`false`) |
| `MOD_AUDIO_FORK_SKIP_SERVER_CERT_HOSTNAME_CHECK` | Skip TLS hostname verification (`true`/`false`) |
| `MOD_AUDIO_FORK_ALLOW_EXPIRED` | Allow expired TLS certificates (`true`/`false`) |

## API

### Command Syntax

```
uuid_audio_fork <uuid> <command> [arguments...]
```

### Commands

#### start

```
uuid_audio_fork <uuid> start <wss-url> <mix-type> <sampling-rate> [bugname] [metadata] [bidirectionalAudio_enabled] [bidirectionalAudio_stream_enabled] [bidirectionalAudio_stream_samplerate]
```

Attaches a media bug and starts streaming audio to the WebSocket server.

| Parameter | Description |
|---|---|
| `uuid` | FreeSWITCH channel UUID |
| `wss-url` | WebSocket URL (`ws://`, `wss://`, `http://`, or `https://`) |
| `mix-type` | `mono` (caller only), `mixed` (caller + callee), or `stereo` (separate channels) |
| `sampling-rate` | `8k`, `16k`, or any integer multiple of 8000 (e.g. `24000`, `32000`, `64000`) |
| `bugname` | Optional bug name for multiple concurrent forks (default: `audio_fork`) |
| `metadata` | Optional JSON metadata sent as a text frame immediately after connecting |
| `bidirectionalAudio_enabled` | `true` or `false` — enable receiving audio from server (default: `true`) |
| `bidirectionalAudio_stream_enabled` | `true` or `false` — enable binary audio streaming from server |
| `bidirectionalAudio_stream_samplerate` | Sample rate of incoming audio from server (e.g. `8000`, `16000`) |

#### stop

```
uuid_audio_fork <uuid> stop [bugname] [metadata]
```

Closes the WebSocket connection and detaches the media bug. Optionally sends a final text frame before closing.

#### send_text

```
uuid_audio_fork <uuid> send_text [bugname] <text>
```

Sends a text frame to the remote server (e.g. DTMF events, control messages).

#### pause

```
uuid_audio_fork <uuid> pause [bugname]
```

Pauses audio streaming (frames are discarded).

#### resume

```
uuid_audio_fork <uuid> resume [bugname]
```

Resumes audio streaming after a pause.

#### graceful-shutdown

```
uuid_audio_fork <uuid> graceful-shutdown [bugname]
```

Initiates a graceful shutdown — stops sending new audio but allows buffered audio to drain before closing.

#### stop_play

```
uuid_audio_fork <uuid> stop_play [bugname]
```

Stops any current audio playback by clearing the playout buffer.

### Events

The module generates the following FreeSWITCH custom events:

| Event | Description |
|---|---|
| `mod_audio_fork::connect` | WebSocket connection established successfully |
| `mod_audio_fork::connect_failed` | WebSocket connection failed (body contains reason) |
| `mod_audio_fork::disconnect` | WebSocket connection closed or server sent disconnect |
| `mod_audio_fork::buffer_overrun` | Audio buffer overrun — frames are being dropped |
| `mod_audio_fork::transcription` | Server sent a transcription message |
| `mod_audio_fork::transfer` | Server sent a transfer request |
| `mod_audio_fork::play_audio` | Server sent audio for playback |
| `mod_audio_fork::kill_audio` | Server requested to stop current audio playback |
| `mod_audio_fork::error` | Server reported an error |
| `mod_audio_fork::json` | Server sent a generic JSON message |

### Server-to-Module Messages

The server can send JSON text frames to control the module:

#### playAudio
Play audio back to the caller (when using base64-encoded JSON mode):
```json
{
  "type": "playAudio",
  "data": {
    "audioContentType": "raw",
    "sampleRate": 8000,
    "audioContent": "<base64-encoded raw audio>"
  }
}
```

#### killAudio
Stop current audio playback and clear buffers:
```json
{
  "type": "killAudio"
}
```

#### mark
Add a named marker for audio synchronization:
```json
{
  "type": "mark",
  "data": {
    "name": "marker-name"
  }
}
```
When the marker is reached during playout, the module sends a mark event back to the server. Maximum 30 markers can be queued.

#### clearMarks
Clear all pending markers:
```json
{
  "type": "clearMarks"
}
```

#### transcription
```json
{
  "type": "transcription",
  "data": { ... }
}
```

#### transfer
```json
{
  "type": "transfer",
  "data": { ... }
}
```

#### disconnect
```json
{
  "type": "disconnect",
  "data": { ... }
}
```

#### error
```json
{
  "type": "error",
  "data": { ... }
}
```

#### Binary Audio Streaming

When `bidirectionalAudio_stream_enabled` is set to `true`, the server can send raw binary audio frames directly over the WebSocket (instead of base64-encoded JSON). This is more efficient for real-time audio streaming. The module handles:

- Automatic resampling if the server's sample rate differs from the channel's rate
- Pre-buffering to smooth out network jitter
- Audio marker interleaving for synchronization

## Building

See [BUILD.md](BUILD.md) for detailed build instructions.

### Quick Start

```bash
# Install dependencies, build, and install
chmod +x build.sh
sudo ./build.sh all

# Or step by step:
sudo ./build.sh deps      # Install build dependencies
./build.sh build           # Build the module
sudo ./build.sh install    # Install to FreeSWITCH
```

## Usage Example

```bash
# Start streaming with bidirectional audio
fs_cli -x "uuid_audio_fork <uuid> start wss://your-server.com/audio mixed 16k mybug {} true true 16000"

# Send a text message
fs_cli -x "uuid_audio_fork <uuid> send_text mybug {\"event\":\"dtmf\",\"digit\":\"1\"}"

# Pause streaming
fs_cli -x "uuid_audio_fork <uuid> pause mybug"

# Resume streaming
fs_cli -x "uuid_audio_fork <uuid> resume mybug"

# Stop with final message
fs_cli -x "uuid_audio_fork <uuid> stop mybug {\"reason\":\"complete\"}"
```

## License

See [LICENSE](LICENSE) for details.
