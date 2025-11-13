#!/bin/bash

swift build -c debug

bash -lc 'cfg='debug'; src=.build/$cfg; dest=GodotProject/bin; mkdir -p "$dest"; cp -f "$src"/*.dylib "$dest" 2>/dev/null || true'

godot --path GodotProject/ --disable-crash-handler &

