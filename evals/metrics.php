<?php

// Static quality metrics for the test code a run added, read from its saved diff.
// Usage: php evals/metrics.php <run>.diff
// Prints one CSV fragment: test_methods,test_loc,loc_per_test,asserts_per_test,logic,loose_asserts,doubles

$files = [];
$current = null;
foreach (preg_split('/\R/', (string) @file_get_contents($argv[1] ?? '')) as $line) {
    if (str_starts_with($line, '+++ ')) {
        $current = preg_match('#^\+\+\+ b/(tests/.+\.php)$#', $line, $m) ? $m[1] : null;
        continue;
    }
    if ($current !== null && str_starts_with($line, '+')) {
        $files[$current] = ($files[$current] ?? '').substr($line, 1)."\n";
    }
}

$methods = $loc = $asserts = $logic = $loose = $doubles = 0;
foreach ($files as $code) {
    // Changed (not new) files only have their added lines; tokenise them as PHP anyway.
    $tokens = token_get_all(str_contains($code, '<?php') ? $code : "<?php\n".$code);

    $plain = '';
    $testAttribute = false;
    foreach ($tokens as $i => $token) {
        [$id, $text] = is_array($token) ? $token : [null, $token];
        if ($id === T_COMMENT || $id === T_DOC_COMMENT) {
            $plain .= str_repeat("\n", substr_count($text, "\n"));
            continue;
        }
        $plain .= $text;

        if ($id === T_ATTRIBUTE && preg_match('/^\s*Test\b/', implode('', array_map(
            fn ($t) => is_array($t) ? $t[1] : $t, array_slice($tokens, $i + 1, 2)
        )))) {
            $testAttribute = true;
        }
        if ($id === T_FUNCTION) {
            $name = $tokens[$i + 2] ?? null;
            if (is_array($name) && $name[0] === T_STRING && ($testAttribute || str_starts_with($name[1], 'test'))) {
                $methods++;
            }
            $testAttribute = false;
        }
        if (in_array($id, [T_IF, T_ELSEIF, T_FOREACH, T_FOR, T_WHILE, T_SWITCH, T_MATCH], true)) {
            $logic++;
        }
    }

    // Pest: it('...') / test('...')
    $methods += preg_match_all('/(?:^|[\s;])(?:it|test)\(\s*[\'"]/m', $plain);

    foreach (preg_split('/\R/', $plain) as $line) {
        $line = trim($line);
        if ($line !== '' && !preg_match('/^(<\?php|namespace |use |declare\()/', $line)) {
            $loc++;
        }
    }

    $asserts += preg_match_all('/\bassert[A-Z]\w*\s*\(|\bexpectException\w*\s*\(|(?<![>\w])expect\s*\(/', $plain);
    $loose += preg_match_all('/\b(?:assertEquals|assertNotEquals|assertEqualsCanonicalizing)\s*\(|->toEqual\s*\(|\bassertTrue\s*\([^;]*[!=]=(?!=)/', $plain);
    $doubles += preg_match_all('/\b(?:createMock|createStub|createPartialMock|createConfiguredMock|getMockBuilder)\s*\(|Mockery::(?:mock|spy|namedMock)\s*\(|->(?:mock|partialMock|spy)\s*\(|::(?:shouldReceive|spy)\s*\(/', $plain);
}

$per = fn (int $n) => $methods > 0 ? round($n / $methods, 1) : '';
echo implode(',', [$methods, $loc, $per($loc), $per($asserts), $logic, $loose, $doubles]), "\n";
