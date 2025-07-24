# Activate starship
eval "$(starship init bash)"

# Set default file permissions
umask 022 # equivalent to 755 for chmod

# Ensure that flox is installed for the user
if ! flox --version &>/dev/null; then
  nix profile install \
      --experimental-features "nix-command flakes" \
      --accept-flake-config \
      'github:flox/flox'
fi

# Add aliases and functions
# list available wifi devices
alias wifi-ls="nmcli device wifi list"

# list available bluetooth devices
bt-ls() {
    echo "Scanning for Bluetooth devices (this may take a few seconds)..."
    # Start the scan in the background and capture its PID
    bluetoothctl --timeout 10 scan on > /dev/null &
    SCAN_PID=$!

    # Give some time for devices to be discovered
    sleep 5

    echo "Available Bluetooth Devices:"
    # Get a list of discovered devices (MAC addresses)
    DEVICES=$(bluetoothctl devices | awk '/Device/ {print $2}')

    if [ -z "$DEVICES" ]; then
        echo "No devices found."
    else
        for MAC in $DEVICES; do
            # Get detailed info for each device
            INFO=$(bluetoothctl info "$MAC")
            NAME=$(echo "$INFO" | grep "Name:" | awk '{print $2}')
            ALIAS=$(echo "$INFO" | grep "Alias:" | awk '{print $2}')

            if [ -n "$NAME" ]; then
                echo "  MAC: $MAC, Name: $NAME"
            elif [ -n "$ALIAS" ]; then
                echo "  MAC: $MAC, Alias: $ALIAS (Name not available)"
            else
                echo "  MAC: $MAC (Name/Alias not available)"
            fi
        done
    fi

    # Stop the background scan process
    kill $SCAN_PID 2>/dev/null
    echo "Scan stopped."
}

# toggle wifi on and off
wifi-toggle() {
  STATUS=$(nmcli radio wifi)
  if [ $STATUS = "enabled" ]; then
    echo "Turning off wifi..."
    nmcli radio wifi off
  else
    echo "Turning on wifi..."
    nmcli radio wifi on
  fi
}

# toggle bluetooth on and off
bt-toggle() {
  STATUS=$(bluetoothctl show | grep "Powered" | awk '{print $2}')
  if [ "$STATUS" = "yes" ]; then
    echo "Turning off Bluetooth..."
    bluetoothctl power off
  else
    echo "Turning on Bluetooth..."
    bluetoothctl power on
  fi
}

# Connect to a wifi network
wifi() {
  if [ -z "$1" ]; then
    echo "Usage: wifi <SSID>"
    return 1
  fi

  local ssid="$1"

  echo "Attempting to connect to Wi-Fi network $ssid"
  nmcli device wifi connec "$ssid" --ask
  if [ $? -eq 0 ]; then
    echo "Successfully connected to $ssid."
  else
    echo "Failed to connect to $ssid."
  fi
}

# Connect to bluetooth device
bt() {
  bluetoothctl connect $1
}

# Disconnect from a wifi device
wifi-dc() {
  if [[ -z "$1" ]]; then
    echo "Usage: disconnect_wifi <connection_name_or_UUID>"
    echo "To list connections: nmcli con show"
    return 1
  fi

  local connection_id="$1"
  echo "Attempting to disconnect from Wi-Fi connection: $connection_id"
  nmcli con down "$connection_id"
  if [[ $? -eq 0 ]]; then
    echo "Successfully disconnected from $connection_id."
  else
    echo "Failed to disconnect from $connection_id. Check connection name or UUID."
  fi
}

# Disconnect from a bluetooth device
bt-dc() {
  bluetoothctl disconnect $1
}

# Show available internet connection
wifi-ps() {
  nmcli con show
}

# Show available bluetooth connections
bt-ps() {
  bluetoothctl devices
}

# Disable flox metrics
FLOX_DISABLE_METRICS=true

# Start the base flox user environment
if [[ -z "$FLOX_PROMPT_ENVIRONMENTS" ]]; then
  flox activate -d ~/.config/base -s && exit
fi
