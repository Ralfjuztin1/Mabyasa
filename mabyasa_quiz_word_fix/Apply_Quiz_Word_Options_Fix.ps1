$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $projectRoot "Scripts\Battle\QuestionFactory.gd"

if (-not (Test-Path -LiteralPath $target)) {
    throw "Could not find Scripts/Battle/QuestionFactory.gd. Extract this ZIP into your MABYASA project root, then run the script again."
}

$content = [System.IO.File]::ReadAllText($target)
$content = $content.Replace("`r`n", "`n").Replace("`r", "`n")

if ($content.Contains("static func _is_single_word_option(text: String) -> bool:")) {
    throw "QuestionFactory.gd already contains the single-word option helper. The fix may already be applied; no changes were made."
}

function Replace-ExactlyOnce {
    param(
        [string]$Source,
        [string]$OldText,
        [string]$NewText,
        [string]$Description
    )
    $count = [System.Text.RegularExpressions.Regex]::Matches(
        $Source,
        [System.Text.RegularExpressions.Regex]::Escape($OldText)
    ).Count
    if ($count -ne 1) {
        throw "Expected to find the $Description exactly once, but found it $count times. No file changes were written. Your code may differ from the repository version."
    }
    return $Source.Replace($OldText, $NewText)
}

$oldAnchor = @'
# FILL BLANK
# ============================================================

static func _build_fill_blank(
'@ -replace "`r`n", "`n"
$newAnchor = @'
# FILL BLANK
# ============================================================

static func _is_single_word_option(text: String) -> bool:
	var cleaned: String = text.strip_edges()
	return (
		not cleaned.is_empty()
		and not cleaned.contains(" ")
		and not cleaned.contains("\t")
		and not cleaned.contains("\n")
		and not cleaned.contains("\r")
	)


static func _build_fill_blank(
'@ -replace "`r`n", "`n"
$content = Replace-ExactlyOnce $content $oldAnchor $newAnchor "fill-blank function anchor"

$oldAnswerCheck = @'
		# Answer part must also have been encountered.
		if not LanguageProgress.is_encountered(
			answer_id
		):

			continue


		var q := QuizQuestion.new()
'@ -replace "`r`n", "`n"
$newAnswerCheck = @'
		# Answer part must also have been encountered.
		if not LanguageProgress.is_encountered(
			answer_id
		):
			continue

		# Fill-blank questions must test a single word, not a full phrase.
		if not _is_single_word_option(answer_entry.kapampangan):
			continue

		var q := QuizQuestion.new()
'@ -replace "`r`n", "`n"
$content = Replace-ExactlyOnce $content $oldAnswerCheck $newAnswerCheck "answer validation block"

$oldDistractorCheck = @'
			var text: String = (
				other.kapampangan
			)


			if text.is_empty():
				continue
'@ -replace "`r`n", "`n"
$newDistractorCheck = @'
			var text: String = (
				other.kapampangan
			)

			# Never use multi-word phrases/sentences as blank-answer distractors.
			if not _is_single_word_option(text):
				continue
'@ -replace "`r`n", "`n"
$content = Replace-ExactlyOnce $content $oldDistractorCheck $newDistractorCheck "fill-blank distractor filter"

$oldOptionsEnd = @'
			options.append(
				{
					"id": other.id,
					"text": text
				}
			)


		options.shuffle()


		for i: int in options.size():

			q.choices.append(
'@ -replace "`r`n", "`n"
$newOptionsEnd = @'
			options.append(
				{
					"id": other.id,
					"text": text
				}
			)


		# If there are not enough single-word distractors, skip this fill-blank
		# and let QuestionFactory try another suitable question type.
		if options.size() < MAX_CHOICES:
			continue

		options.shuffle()


		for i: int in options.size():

			q.choices.append(
'@ -replace "`r`n", "`n"
$content = Replace-ExactlyOnce $content $oldOptionsEnd $newOptionsEnd "fill-blank option finalization block"

# Keep a recoverable copy next to the script before writing the updated file.
$backup = "$target.before_single_word_options.bak"
if (-not (Test-Path -LiteralPath $backup)) {
    [System.IO.File]::Copy($target, $backup, $false)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($target, $content, $utf8NoBom)
Write-Host "Applied fix to Scripts/Battle/QuestionFactory.gd" -ForegroundColor Green
Write-Host "Fill-blank answers and distractors are now limited to single Kapampangan words. Phrase-based and sentence-building questions are unchanged."
Write-Host "Backup saved as Scripts/Battle/QuestionFactory.gd.before_single_word_options.bak"
