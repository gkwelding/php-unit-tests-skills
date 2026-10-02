#!/usr/bin/env bash
# Blind side-by-side review of the tests the two variants wrote for each target in a results folder.
# The suites are shown as A and B in random order; verdicts are mapped back to with/without.
#
# Usage: evals/judge.sh <results folder>     (run.sh calls this at the end unless JUDGE=0)
# Env:   MODEL             model for claude -p (default: your claude default)
#        JUDGE_BUDGET_USD  spend cap per comparison (default 1)
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$1" # relative paths from here also work with a native Windows php
budget=${JUDGE_BUDGET_USD:-1}

criteria=(readability simplicity focus effectiveness overall)
props=""
for c in "${criteria[@]}"; do
    props+="\"$c\":{\"type\":\"object\",\"properties\":{\"winner\":{\"type\":\"string\",\"enum\":[\"A\",\"B\",\"tie\"]},\"reason\":{\"type\":\"string\"}},\"required\":[\"winner\",\"reason\"]},"
done
required=$(printf '"%s",' "${criteria[@]}")
schema="{\"type\":\"object\",\"properties\":{${props%,}},\"required\":[${required%,}]}"

# a_was says which variant was shown as A; the reasons refer to the suites as A and B.
echo "framework,target,criterion,winner,a_was,reason" > judge.csv

tail -n +2 results.csv | cut -d, -f1,2 | sort -u | while IFS=, read -r fw target; do
    name=$fw-$(basename "$target" .php)
    [ -f "$name-with.diff" ] && [ -f "$name-without.diff" ] || continue

    # Random order, so position can't favour a variant.
    if (( RANDOM % 2 )); then a=with b=without; else a=without b=with; fi

    fixtures=$root/evals/fixtures/$fw
    case $fw in laravel) base=app ;; symfony) base=src ;; esac
    {
        cat <<'EOF'
Two test suites, A and B, were written independently for the same PHP code. Compare only the test code.

For each criterion, pick A, B or tie, and give one sentence that cites something specific in the tests:
- readability: easier to understand at a glance. Names say the scenario and the outcome; setup, action and check are easy to tell apart.
- simplicity: less noise. Only the setup each test needs; no logic, indirection or helpers that hide what is being tested.
- focus: each test checks one behaviour, so a failure points straight at its cause.
- effectiveness: more likely to catch a real regression in the code under test, without breaking on harmless refactors.
- overall: the suite you would rather maintain.

Judge quality, not quantity: more tests is not better by itself.
EOF
        echo
        echo "=== Code under test ==="
        echo "// $target"
        cat "$fixtures/$target"
        # Include the app classes the target imports (Form Request, DTO, model, mail, ...).
        { grep -oE '^use App\\[A-Za-z\\]+;' "$fixtures/$target" || true; } | sed -E 's/^use App\\//; s/;$//; s#\\#/#g' |
            while read -r class; do
                [ -f "$fixtures/$base/$class.php" ] && { echo; echo "// $base/$class.php"; cat "$fixtures/$base/$class.php"; }
            done
        echo
        echo "=== Suite A ==="
        php "$root/evals/metrics.php" --code "$name-$a.diff"
        echo "=== Suite B ==="
        php "$root/evals/metrics.php" --code "$name-$b.diff"
    } > "$name.judge-prompt.txt"

    echo "== judging $name (A = $a)"
    claude -p --tools "" --setting-sources project --output-format json --json-schema "$schema" --max-budget-usd "$budget" \
        --no-session-persistence ${MODEL:+--model "$MODEL"} \
        < "$name.judge-prompt.txt" > "$name.judge.json" 2> "$name.judge.err" || echo "   judge failed, see $name.judge.err"

    php -r '
        [, $json, $a, $b, $fw, $target] = $argv;
        $verdict = json_decode((string) @file_get_contents($json), true)["structured_output"] ?? [];
        $out = fopen("judge.csv", "a");
        foreach ($verdict as $criterion => $v) {
            $winner = ["A" => $a, "B" => $b][$v["winner"]] ?? "tie";
            fputcsv($out, [$fw, $target, $criterion, $winner, $a, $v["reason"]], escape: "");
        }
    ' "$name.judge.json" "$a" "$b" "$fw" "$target"
done

php -r '
    $rows = array_map(fn ($l) => str_getcsv($l, escape: ""), array_slice(file("judge.csv", FILE_IGNORE_NEW_LINES), 1));
    $tally = [];
    foreach ($rows as [, , $criterion, $winner]) {
        $tally[$criterion][$winner] = ($tally[$criterion][$winner] ?? 0) + 1;
    }
    printf("\n%-14s %5s %8s %4s\n", "criterion", "with", "without", "tie");
    foreach ($tally as $criterion => $t) {
        printf("%-14s %5d %8d %4d\n", $criterion, $t["with"] ?? 0, $t["without"] ?? 0, $t["tie"] ?? 0);
    }
'
echo
echo "Verdicts with reasons: $1/judge.csv"
