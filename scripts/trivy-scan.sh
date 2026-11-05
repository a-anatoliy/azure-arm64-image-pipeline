#!/bin/sh
# Runs inside the build VM (as root). Scans the file system with Trivy and
# writes /tmp/trivy-report.txt, which Packer downloads as a build artifact.
set -eu

: "${TRIVY_VERSION:?TRIVY_VERSION is required}"
FAIL_ON_CRITICAL="${FAIL_ON_CRITICAL:-false}"
TRIVY_DIR=/tmp/trivy
REPORT=/tmp/trivy-report.txt
SKIP_DIRS=/proc,/sys,/dev,/run,/tmp

# Pinned release; the install script verifies the archive checksum.
mkdir -p "$TRIVY_DIR"
curl -sSfL "https://raw.githubusercontent.com/aquasecurity/trivy/v${TRIVY_VERSION}/contrib/install.sh" \
  | sh -s -- -b "$TRIVY_DIR" "v${TRIVY_VERSION}"
"$TRIVY_DIR/trivy" --version

# Report: fixable HIGH and CRITICAL findings.
"$TRIVY_DIR/trivy" rootfs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed \
  --skip-dirs "$SKIP_DIRS" --format table --output "$REPORT" /
chmod 0644 "$REPORT"
echo "Trivy report: $(wc -l < "$REPORT") lines"

# Gate: fail on fixable CRITICAL findings only when requested.
gate_exit=0
if [ "$FAIL_ON_CRITICAL" = "true" ]; then
  gate_exit=1
fi
"$TRIVY_DIR/trivy" rootfs --scanners vuln --severity CRITICAL --ignore-unfixed \
  --skip-dirs "$SKIP_DIRS" --exit-code "$gate_exit" --quiet --format table /
