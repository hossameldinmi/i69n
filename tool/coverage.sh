#!/bin/bash
set -e

# Run tests with coverage
dart test --coverage=coverage

# Format coverage to LCOV
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib

echo "Coverage report generated at coverage/lcov.info"
