#!/usr/bin/env nu

use ./shared.nu [retry]

const DEFAULT_TIMELIMIT = 300

def main [host: string, --timelimit: int = 300, --baseline, --backend: string] {
    retry { ^rsync -avr --del --exclude "archive" $"(git rev-parse --show-toplevel)/nix" $"($host):." }
    retry { ^rsync -avr --del --exclude "archive" $"(git rev-parse --show-toplevel)/benchmark" $"($host):." }

    let args = $"($host) --timelimit ($timelimit) (if $baseline { "--baseline" }) --backend ($backend)"

    retry { ^ssh $host "if systemctl is-active benchmark; then sudo systemctl stop benchmark; fi" }
    retry { ^ssh $host "if systemctl is-failed benchmark; then sudo systemctl reset-failed benchmark; fi" }

    let user = ^ssh $host "whoami"

    retry { ssh $host $'sudo systemd-run --unit benchmark --service-type exec -E PATH="$PATH" --property User=($user) --property TimeoutSec=infinity --working-directory "$HOME/benchmark" "$HOME/benchmark/main.nu" ($args)' }

    ^ssh $host 'sudo journalctl -xe --invocation "$(systemctl show --value -p InvocationID benchmark)" -f'
}

def "main pull-results" [host: string] {
    ^rsync -avr --del $"($host):archive" $"(git rev-parse --show-toplevel)/benchmark"
}
