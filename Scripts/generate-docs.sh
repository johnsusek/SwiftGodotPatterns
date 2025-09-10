#!/bin/sh

swift package --allow-writing-to-directory "docs" generate-documentation --target SwiftGodotPatterns --include-extended-types --transform-for-static-hosting --hosting-base-path "SwiftGodotPatterns" --output-path "docs/"
