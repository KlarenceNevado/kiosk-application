#!/bin/bash
# Add Flutter to the PATH if it's not already there
if ! grep -q "flutter/bin" ~/.bashrc; then
  echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
  echo "Flutter added to PATH in .bashrc"
else
  echo "Flutter already in PATH"
fi

# Set the current session path as well
export PATH="$PATH:$HOME/flutter/bin"

# Verify Flutter
flutter --version
