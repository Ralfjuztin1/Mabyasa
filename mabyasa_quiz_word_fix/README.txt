MABYASA: SINGLE-WORD FILL-BLANK OPTIONS FIX

WHAT THIS FIX DOES
- Fill-in-the-blank questions show only single Kapampangan words as options.
- Full phrases such as "Mayap a abak" and "Ala pung nanu man" are not used as distractors for a one-word blank.
- If there are not enough encountered single-word choices for a full choice set, that fill-blank question is skipped and the question factory can try another question type.
- Multiple-choice, translation, matching, and boss sentence-building questions are not changed.

INSTALL
1. Make a backup of your MABYASA project first.
2. Extract this ZIP into the root of your project, e.g. C:\Users\Ralf\Music\MABYASA.
3. Open Command Prompt or PowerShell in that project folder and run:
   powershell -ExecutionPolicy Bypass -File .\Apply_Quiz_Word_Options_Fix.ps1
4. The script updates Scripts\Battle\QuestionFactory.gd and creates a backup next to it:
   Scripts\Battle\QuestionFactory.gd.before_single_word_options.bak
5. Open or return to Godot and test the Chief training battle.

If the script reports that a code block was not found exactly once, it makes no changes. That means the local file differs from the version this fix was prepared for; do not force the replacement.

This ZIP does not modify or commit the GitHub repository. Test in Godot before committing your local change.
