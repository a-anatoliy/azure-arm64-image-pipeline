#!/bin/bash
# Runs inside the smoke-test VM through "az vm run-command" (as root).
# run-command does not return the script's exit code, so the result is
# printed as a SMOKE_TEST_RESULT=PASS|FAIL line and parsed by smoke-test.sh.
set -u

failures=0
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $name"
  else
    echo "FAIL  $name"
    failures=$((failures + 1))
  fi
}

check "architecture is aarch64"          test "$(uname -m)" = aarch64
check "image metadata present"            grep -q '^IMAGE_VERSION=' /etc/image-release
check "cloud-init finished"               sh -c 'cloud-init status --wait; [ $? -le 2 ]'
check "Azure agent running"               systemctl is-active --quiet walinuxagent
check "sshd: password login disabled"     sh -c 'sshd -T | grep -qx "passwordauthentication no"'
check "sshd: root login disabled"         sh -c 'sshd -T | grep -qx "permitrootlogin no"'
check "auditd running"                    systemctl is-active --quiet auditd
check "chrony running"                    systemctl is-active --quiet chrony
check "ASLR enabled"                      test "$(sysctl -n kernel.randomize_va_space)" = 2
check "ICMP redirects ignored"            test "$(sysctl -n net.ipv4.conf.all.accept_redirects)" = 0
check "automatic security updates on"     grep -q 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades

echo "--- /etc/image-release"
cat /etc/image-release 2>/dev/null

if [ "$failures" -eq 0 ]; then
  echo "SMOKE_TEST_RESULT=PASS"
else
  echo "SMOKE_TEST_RESULT=FAIL ($failures failed)"
fi
