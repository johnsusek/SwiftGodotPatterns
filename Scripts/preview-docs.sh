#!/bin/sh

swift package --disable-sandbox preview-documentation --target SwiftGodotPatterns --include-extended-types --output-path docs
