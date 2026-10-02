#!/usr/bin/env bash
# Generate tests for each fixture target with and without the skills, then score them:
# tests run, failures, errors, skipped, and Infection's mutation score (MSI) on the target.
#
# Usage: evals/run.sh [all|laravel|symfony|<part of a target path>]   e.g. evals/run.sh Calculator
# Env:   MODEL       model for claude -p (default: your claude default)
#        BUDGET_USD  spend cap per claude run (default 5)
#        WORK        scratch directory for the scaffolded apps (default evals/.work)
#        COVERAGE_PHP_OPTS  php options that load a coverage driver for Infection's initial run,
#                    e.g. "-d zend_extension=/path/to/xdebug.dll" when it isn't enabled in php.ini
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=${WORK:-$root/evals/.work}
budget=${BUDGET_USD:-5}
which=${1:-all}
stamp=$(date +%Y%m%d-%H%M%S)
results=$work/results/$stamp
mkdir -p "$results"
csv=$results/results.csv
echo "framework,target,variant,tests,failures,errors,skipped,msi" > "$csv"

# framework|target|comma-separated files Infection mutates
targets=(
    "laravel|app/Services/DiscountCalculator.php|app/Services/DiscountCalculator.php"
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
    printf '{"source": {"directories": ["%s"]}, "testFramework": "phpunit"}\n' "$src" > "$dir/infection.json5"
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
        --max-budget-usd "$budget" --no-session-persistence --permission-mode acceptEdits \
        --allowedTools "Read,Write,Edit,Glob,Grep,Bash(php:*),Bash(vendor/bin/phpunit:*),Bash(vendor/bin/pest:*),Bash(vendor/bin/phpstan:*),Bash(vendor/bin/pint:*),Bash(vendor/bin/php-cs-fixer:*),Bash(bin/phpunit:*),Bash(bin/console:*),Bash(composer dump-autoload:*),Bash(git diff:*),Bash(git status:*)" \
        > "$out.claude.txt" 2>&1) || echo "   claude exited non-zero, see $results/$name.claude.txt"
    (cd "$dir" && git add -A 2>/dev/null && git diff --cached -- . ':!.claude' > "$out.diff")
    (cd "$dir" && vendor/bin/phpunit --log-junit "$out.junit.xml" > "$out.phpunit.txt" 2>&1) || true
    # Infection refuses to run if the suite fails; the msi column is then blank.
    # auto_prepend_file is cleared because Infection rejects it (Laravel Herd sets one).
    local files
    IFS=, read -ra files <<< "$filter"
    # --with-uncovered counts target code no test reaches as surviving mutants.
    (cd "$dir" && php -d auto_prepend_file= vendor/bin/infection --threads=max --no-progress --with-uncovered \
        ${COVERAGE_PHP_OPTS:+--initial-tests-php-options="$COVERAGE_PHP_OPTS"} \
        --logger-summary-json="$out.infection.json" "${files[@]}" > "$out.infection.txt" 2>&1) || true

    (cd "$dir" && php -r '
        [, $junit, $infection, $row] = $argv;
        $suite = is_file($junit) ? simplexml_load_file($junit)->testsuite : null;
        $stats = is_file($infection) ? json_decode(file_get_contents($infection), true)["stats"] : [];
        $counts = $suite ? "{$suite["tests"]},{$suite["failures"]},{$suite["errors"]},{$suite["skipped"]}" : ",,,";
        echo "$row,$counts,", $stats["msi"] ?? "", "\n";
    ' "$out.junit.xml" "$out.infection.json" "$fw,$target,$variant") >> "$csv"
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
