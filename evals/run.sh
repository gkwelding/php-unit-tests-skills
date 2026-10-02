#!/usr/bin/env bash
# Generate tests for each fixture target with and without the skills, then score them:
# tests run, failures, errors, skipped, and Infection's mutation score (MSI) on the target.
#
# Usage: evals/run.sh [all|laravel|symfony|<part of a target path>]   e.g. evals/run.sh Calculator
# Env:   MODEL       model for claude -p (default: your claude default)
#        BUDGET_USD  spend cap per claude run (default 5)
#        WORK        scratch directory for the scaffolded apps (default evals/.work)
#        COVERAGE_PHP_OPTS  php options that load a coverage driver for the coverage run,
#                    e.g. "-d zend_extension=/path/to/xdebug.dll" when it isn't enabled in php.ini (no spaces in the path)
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=${WORK:-$root/evals/.work}
budget=${BUDGET_USD:-5}
which=${1:-all}
stamp=$(date +%Y%m%d-%H%M%S)
results=$work/results/$stamp
mkdir -p "$results"
csv=$results/results.csv
echo "framework,target,variant,tests,failures,errors,skipped,msi,cost_usd,turns,minutes" > "$csv"

# framework|target|comma-separated files Infection mutates
targets=(
    "laravel|app/Services/DiscountCalculator.php|app/Services/DiscountCalculator.php"
    "laravel|app/Actions/ShipOrder.php|app/Actions/ShipOrder.php"
    "laravel|app/Http/Controllers/CustomerController.php|app/Http/Controllers/CustomerController.php,app/Http/Requests/StoreCustomerRequest.php"
    "symfony|src/Service/ShippingCostCalculator.php|src/Service/ShippingCostCalculator.php"
    "symfony|src/Controller/OrderController.php|src/Controller/OrderController.php,src/Dto/CreateOrderDto.php"
)

export XDEBUG_MODE=coverage
if [ -z "${COVERAGE_PHP_OPTS:-}" ] && ! php -m | grep -qiE '^(xdebug|pcov)$'; then
    echo "warning: no pcov or xdebug loaded and COVERAGE_PHP_OPTS unset, so the msi column will be blank" >&2
fi

scaffold() {
    local fw=$1 dir=$work/$1 src
    case $fw in laravel) src=app ;; symfony) src=src ;; esac
    if [ ! -d "$dir/.git" ]; then
        rm -rf "$dir"
        case $fw in
            laravel)
                composer create-project -n --quiet laravel/laravel "$dir"
                (cd "$dir" && composer config allow-plugins.infection/extension-installer true \
                    && composer require -n --quiet --dev infection/infection)
                echo "require __DIR__.'/customers.php';" >> "$dir/routes/web.php" ;;
            symfony)
                composer create-project -n --quiet symfony/skeleton "$dir"
                (cd "$dir" && composer config allow-plugins.infection/extension-installer true \
                    && composer require -n --quiet symfony/clock symfony/serializer symfony/property-access symfony/property-info symfony/validator \
                    && composer require -n --quiet --dev symfony/test-pack infection/infection) ;;
        esac
        (cd "$dir" && git init -q)
    fi

    # Copy fixtures and config on every run so edits reach an existing scaffold.
    # Package changes still need a fresh scaffold: delete $work/<framework>.
    (cd "$dir" && if git rev-parse -q --verify HEAD > /dev/null; then git reset -q --hard && git clean -qfd; fi)
    cp -r "$root/evals/fixtures/$fw/." "$dir/"
    # PublicVisibility is off: it says nothing about test quality, and coverage never marks a
    # controller action's signature line, so it would count as surviving for every variant.
    # ArrayItemRemoval removes each item in turn (default: only the first), so a payload or rules
    # array has one mutant per entry.
    printf '{"source": {"directories": ["%s"]}, "testFramework": "phpunit", "mutators": {"@default": true, "PublicVisibility": false, "ArrayItemRemoval": {"settings": {"remove": "all"}}}}\n' \
        "$src" > "$dir/infection.json5"
    (cd "$dir" && git add -A 2>/dev/null \
        && { git diff --cached --quiet || git -c user.name=eval -c user.email=eval@localhost commit -qm baseline; })
}

run_one() {
    local fw=$1 target=$2 filter=$3 variant=$4 dir=$work/$1 name prompt
    name=$fw-$(basename "$target" .php)-$variant
    # Paths below are relative to $dir so they also work with a native Windows php.
    local out=../results/$stamp/$name

    (cd "$dir" && git reset -q --hard && git clean -qfd)
    if [ "$variant" = with ]; then
        mkdir -p "$dir/.claude/skills"
        cp -r "$root"/skills/* "$dir/.claude/skills/"
        prompt="/generate-php-tests $target"
    else
        prompt="Write tests for $target following the project's conventions, then run them and make sure they pass."
    fi

    echo "== $name"
    # MSYS_NO_PATHCONV stops Git Bash on Windows rewriting "/generate-php-tests" into a file path.
    (cd "$dir" && MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' claude -p "$prompt" ${MODEL:+--model "$MODEL"} \
        --max-budget-usd "$budget" --no-session-persistence --permission-mode acceptEdits --output-format json \
        --allowedTools "Read,Write,Edit,Glob,Grep,Bash(php:*),Bash(vendor/bin/phpunit:*),Bash(vendor/bin/pest:*),Bash(vendor/bin/phpstan:*),Bash(vendor/bin/pint:*),Bash(vendor/bin/php-cs-fixer:*),Bash(bin/phpunit:*),Bash(bin/console:*),Bash(composer dump-autoload:*),Bash(git diff:*),Bash(git status:*)" \
        > "$out.claude.json" 2> "$out.claude.err") || echo "   claude exited non-zero, see $results/$name.claude.err"
    # Keep Claude's final message readable next to the raw JSON.
    (cd "$dir" && php -r '$j = json_decode((string) @file_get_contents($argv[1]), true); file_put_contents($argv[2], $j["result"] ?? "");' \
        "$out.claude.json" "$out.claude.txt")
    (cd "$dir" && git add -A 2>/dev/null && git diff --cached -- . ':!.claude' > "$out.diff")

    # #[CoversClass] and friends narrow which code PHPUnit credits a test with, so code the tests
    # do exercise (a DTO behind a controller) would score as uncovered. Strip that metadata in the
    # scratch app before scoring; the saved diff keeps the tests as written.
    [ -d "$dir/tests" ] && find "$dir/tests" -name '*.php' \
        -exec perl -i -ne 'print unless /^\s*#\[Covers\w*(\(.*\))?\]\s*$/ || /\@covers/' {} +
    # One PHPUnit run gives the counts and the coverage Infection needs. Infection's own initial run
    # is skipped: inside Infection it exits part-way through Symfony WebTestCase suites that pass
    # when PHPUnit is run directly. auto_prepend_file is cleared because Infection rejects it
    # (Laravel Herd sets one).
    #
    # PAO_DISABLE=1 turns off laravel/pao, which Laravel 13 skeletons ship: when it detects an AI agent
    # (CLAUDECODE, AI_AGENT, ...) it switches PHPUnit to JSON output, which Infection can't parse, so
    # every mutant run reads as a failure and every mutant as killed. claude -p above still gets pao.
    local cov=$out.coverage junit=$out.coverage/junit.xml
    # shellcheck disable=SC2086 # COVERAGE_PHP_OPTS is a list of php options
    (cd "$dir" && PAO_DISABLE=1 php -d auto_prepend_file= ${COVERAGE_PHP_OPTS:-} vendor/bin/phpunit \
        --coverage-xml="$cov/coverage-xml" --log-junit="$junit" > "$out.phpunit.txt" 2>&1) || true

    # Mutation scores only mean something against a green suite: a failing test "kills" every
    # mutant. With failures or no coverage the msi column stays blank.
    local files
    IFS=, read -ra files <<< "$filter"
    if (cd "$dir" && [ -d "$cov/coverage-xml" ] && php -r '
            $x = @simplexml_load_file($argv[1]);
            exit($x && (int) $x->testsuite["failures"] + (int) $x->testsuite["errors"] === 0 ? 0 : 1);
        ' "$junit"); then
        # --with-uncovered counts target code no test reaches as surviving mutants.
        (cd "$dir" && PAO_DISABLE=1 php -d auto_prepend_file= vendor/bin/infection --threads=max --no-progress --with-uncovered \
            --coverage="$cov" --skip-initial-tests \
            --logger-summary-json="$out.infection.json" "${files[@]}" > "$out.infection.txt" 2>&1) || true
    fi

    (cd "$dir" && php -r '
        [, $junit, $infection, $claude, $row] = $argv;
        $suite = is_file($junit) ? simplexml_load_file($junit)->testsuite : null;
        $stats = is_file($infection) ? json_decode(file_get_contents($infection), true)["stats"] : [];
        $run = json_decode((string) @file_get_contents($claude), true) ?? [];
        $counts = $suite ? "{$suite["tests"]},{$suite["failures"]},{$suite["errors"]},{$suite["skipped"]}" : ",,,";
        $cost = isset($run["total_cost_usd"]) ? round($run["total_cost_usd"], 2) : "";
        $minutes = isset($run["duration_ms"]) ? round($run["duration_ms"] / 60000, 1) : "";
        echo "$row,$counts,", $stats["msi"] ?? "", ",$cost,", $run["num_turns"] ?? "", ",$minutes\n";
    ' "$junit" "$out.infection.json" "$out.claude.json" "$fw,$target,$variant") >> "$csv"
}

for entry in "${targets[@]}"; do
    IFS='|' read -r fw target filter <<< "$entry"
    [ "$which" = all ] || [ "$which" = "$fw" ] || [[ "$target" == *"$which"* ]] || continue
    scaffold "$fw"
    for variant in without with; do
        run_one "$fw" "$target" "$filter" "$variant"
    done
done

echo
column -s, -t < "$csv" 2>/dev/null || cat "$csv"
echo
echo "Logs, diffs and results.csv: $results"
