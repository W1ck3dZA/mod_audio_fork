# Building mod_audio_fork

## Prerequisites

### 1. FreeSWITCH

You need a working FreeSWITCH installation with development headers.

**From packages (Debian/Ubuntu):**
```bash
sudo apt-get install -y freeswitch freeswitch-dev
```

**From source:**
```bash
git clone https://github.com/signalwire/freeswitch.git
cd freeswitch
./bootstrap.sh
./configure
make
sudo make install
```

### 2. Build Dependencies

```bash
sudo apt-get update
sudo apt-get install -y cmake build-essential libwebsockets-dev libboost-all-dev
```

## Building

### Using build.sh (Recommended)

The `build.sh` script handles dependencies, building, and installation:

```bash
chmod +x build.sh

# Do everything: install deps, build, and install
sudo ./build.sh all

# Or run individual steps:
sudo ./build.sh deps      # Install build dependencies only
./build.sh build           # Configure and build only
sudo ./build.sh install    # Install the .so to FreeSWITCH modules dir only
./build.sh --help          # Show usage and options
```

#### Environment Variables

You can override default paths via environment variables:

| Variable | Default | Description |
|---|---|---|
| `FREESWITCH_INCLUDE_DIR` | `/usr/local/freeswitch/include/freeswitch` | Path to FreeSWITCH headers |
| `FREESWITCH_LIBRARY` | `/usr/local/freeswitch/lib/libfreeswitch.so` | Path to FreeSWITCH shared library |
| `FREESWITCH_MOD_DIR` | `/usr/local/freeswitch/mod` | Directory to install the module |
| `BUILD_TYPE` | `Release` | CMake build type (`Release` or `Debug`) |

Example with custom paths:
```bash
FREESWITCH_INCLUDE_DIR=/usr/include/freeswitch \
FREESWITCH_LIBRARY=/usr/lib/libfreeswitch.so \
FREESWITCH_MOD_DIR=/usr/lib/freeswitch/mod \
./build.sh all
```

### Manual Build

```bash
mkdir build
cd build

cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DFREESWITCH_INCLUDE_DIR="/usr/local/freeswitch/include/freeswitch" \
  -DFREESWITCH_LIBRARY="/usr/local/freeswitch/lib/libfreeswitch.so"

make -j$(nproc)
```

Then install:
```bash
sudo cp mod_audio_fork.so /usr/local/freeswitch/mod/
sudo chown freeswitch:freeswitch /usr/local/freeswitch/mod/mod_audio_fork.so
```

## Installation & Configuration

### 1. Load the Module

Add to your FreeSWITCH `modules.conf.xml`:
```xml
<load module="mod_audio_fork"/>
```

### 2. Restart FreeSWITCH

```bash
sudo systemctl restart freeswitch
```

Or reload from fs_cli:
```bash
fs_cli -x "reload mod_audio_fork"
```

### 3. Verify

```bash
fs_cli -x "module_exists mod_audio_fork"
```

## Troubleshooting

### Common Issues

| Problem | Solution |
|---|---|
| Module not found | Verify `mod_audio_fork.so` is in the FreeSWITCH modules directory |
| Permission denied | Ensure the file is owned by `freeswitch:freeswitch` |
| Missing dependencies | Run `ldd mod_audio_fork.so` to check for unresolved symbols |
| Build errors | Ensure FreeSWITCH headers and all dependencies are installed |

### Debug Logging

Check FreeSWITCH logs:
```bash
tail -f /var/log/freeswitch/freeswitch.log
```

Or set debug level in fs_cli:
```bash
fs_cli -x "console loglevel debug"
```

### Verify Library Dependencies

```bash
ldd /usr/local/freeswitch/mod/mod_audio_fork.so
```
