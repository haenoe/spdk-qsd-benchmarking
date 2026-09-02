#!/usr/bin/env nu

# pidstat-averages.nu
#
# Reads every '*.pidstat.json' file under a directory and, for each entry of
# the time-series data (metric -> process -> [values...]), computes the
# average of that series. Results are written next to each input file as
# '<name>.pidstat.averaged.json'.
#
# The pidstat JSON layout is:
#   {
#     "<metric>": {                 # e.g. "cpu", "pct_usr", "rss", ...
#       "<process(pid)>": [ v0, v1, v2, ... ],   # time-series samples
#       ...
#     },
#     ...
#   }
#
# The averaged output keeps the same nested shape, replacing each series with
# its mean:
#   {
#     "<metric>": { "<process(pid)>": <average>, ... },
#     ...
#   }
#
# Usage:
#   nu pidstat-averages.nu                 # scan current dir
#   nu pidstat-averages.nu <root-dir>      # scan a given directory

def "main" [
    root: string = "."   # directory to search for *.pidstat.json files
] {
    let files = (glob $"($root)/**/*.pidstat.json")

    if ($files | is-empty) {
        print $"No '*.pidstat.json' files found under ($root)"
        return
    }

    for file in $files {
        let data = (open --raw $file | from json)

        # data is a record: metric -> record(process -> list of samples)
        let averaged = ($data | columns | reduce --fold {} {|metric, macc|
            let procs = ($data | get $metric)
            let metric_avgs = ($procs | columns | reduce --fold {} {|proc, pacc|
                let series = ($procs | get $proc)
                let nums = ($series | where ($it | describe) in ["int" "float"])
                let avg = (if ($nums | is-empty) { null } else { $nums | math avg })
                $pacc | insert $proc $avg
            })
            $macc | insert $metric $metric_avgs
        })

        let out = ($file | str replace --regex '\.pidstat\.json$' '.pidstat.averaged.json')
        $averaged | to json | save --force $out
        print $"wrote ($out)"
    }
}
