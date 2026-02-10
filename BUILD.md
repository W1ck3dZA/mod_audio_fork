# Building mod_audio_fork on Ubuntu 22.04

This guide will help you build and install `mod_audio_fork` on Ubuntu 22.04.

## Prerequisites

### 1. Install FreeSWITCH

First, you need to install FreeSWITCH. You have two options:

#### Option A: Install from packages (Recommended)

```bash
sudo apt-get update
sudo apt-get install -y freeswitch freeswitch-dev
```

#### Option B: Build from source

```bash
git clone https://github.com/signalwire/freeswitch.git
cd freeswitch
./bootstrap.sh
./configure
make
sudo make install
```

### 2. Install Build Dependencies

The build script will automatically install these, but you can install them manually:

```bash
sudo apt-get update
sudo apt-get install -y \
    cmake \
    libwebsockets-dev \
    libboost-all-dev
```

## Building the Module

### Quick Build (Recommended)

1. Navigate to the mod_audio_fork directory:

```bash
cd mod_audio_fork
```

2. Make the build script executable:

```bash
chmod +x build.sh
```

3. Run the build script:

```bash
./build.sh
```

The script will:

- Check for all dependencies
- Install missing packages automatically
- Configure and build the module
- Offer to install it to the FreeSWITCH modules directory

### Manual Build

If you prefer to build manually:

1. Create build directory:

```bash
mkdir build
cd build
```

2. Configure with CMake:

```bash
cmake .. -DCMAKE_BUILD_TYPE=Release -DFREESWITCH_INCLUDE_DIR="/usr/local/freeswitch/include/freeswitch" -DFREESWITCH_LIBRARY="/usr/local/freeswitch/lib/libfreeswitch.so"
```

3. Build:

```bash
make -j$(nproc)
```

4. Install:

```bash
sudo cp mod_audio_fork.so /usr/local/freeswitch/mod
sudo chown freeswitch:freeswitch /usr/local/freeswitch/mod/mod_audio_fork.so
```

## Installation and Configuration

### 1. Load the Module

Add the following line to your FreeSWITCH configuration file `/etc/freeswitch/modules.conf.xml`:

```xml
<load module="mod_audio_fork"/>
```

### 2. Restart FreeSWITCH

```bash
sudo systemctl restart freeswitch
```

### 3. Verify Installation

Connect to FreeSWITCH CLI and check if the module is loaded:

```bash
fs_cli -x "show modules | grep audio_fork"
```

You should see `mod_audio_fork` in the list.

## Usage

### Basic Usage

Start audio streaming with bidirectional audio support:

```bash
fs_cli -x "uuid_audio_fork <uuid> start <wss-url> mixed 8k"
```

### Parameters

- `<uuid>`: The FreeSWITCH call UUID
- `<wss-url>`: WebSocket URL (ws:// or wss://)
- `mixed`: Enables bidirectional audio (incoming audio will be played back)
- `8k`: Sample rate (8k or 16k)

### Example

```bash
fs_cli -x "uuid_audio_fork 12345678-1234-1234-1234-123456789012 start wss://your-server.com/audio mixed 8k"
```

### Commands

- `start`: Start audio streaming
- `stop`: Stop audio streaming
- `pause`: Pause audio streaming
- `resume`: Resume audio streaming
- `send_text`: Send text message to WebSocket
- `stop_play`: Stop audio playback

## Troubleshooting

### Common Issues

1. **Module not found**: Make sure FreeSWITCH is installed and the module is in the correct directory
2. **Dependencies missing**: Run the build script which will install missing dependencies
3. **Permission denied**: Make sure the module file is owned by freeswitch:freeswitch
4. **Build errors**: Check that all dependencies are installed and FreeSWITCH headers are available

### Debug Information

Check FreeSWITCH logs for errors:

```bash
tail -f /var/log/freeswitch/freeswitch.log
```

### Verify Dependencies

Check if the module has all required dependencies:

```bash
ldd /usr/lib/freeswitch/mod/libmod_audio_fork.so
```

## Features

- **Bidirectional Audio**: Stream audio to WebSocket and receive audio back for playback
- **Multiple Audio Formats**: Support for raw, WAV, MP3, and OGG audio
- **Sample Rate Conversion**: Automatic resampling between different sample rates
- **Audio Markers**: Support for audio markers and synchronization
- **TLS Support**: Secure WebSocket connections with TLS
- **High Performance**: Optimized for low-latency audio streaming

## Support

For issues and questions:

- Check the FreeSWITCH logs
- Verify all dependencies are installed
- Ensure FreeSWITCH is properly configured
- Test with a simple WebSocket server first
