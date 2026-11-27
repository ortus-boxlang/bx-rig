# Rules for anyone who writes code in this repository

## Every BoxLang function has DocBox docs

Every function in every BoxLang class (`.bx`) and script has a DocBox comment, **public or private**. So does every class. This holds for all new code and for every function you change.

```boxlang
/**
 * Splits a skipped step's reason into the text for people and the command to do it later.
 *
 * @param reason The reason a step was skipped, for example "could not run (exit 4): error: ...; do it later: bxrig ...".
 *
 * @return A struct { why, fix }: the cleaned reason and the command ("" when there is none).
 */
function split( reason ) {
	...
}
```

- Start with a one-sentence summary of what the function does (not how). Add detail below it when the behaviour is not obvious: units, what an empty value means, side effects, exit codes.
- `@param NAME` for every argument (what it is, its unit or allowed values, its default when it has one) and `@return` for what comes back. Say when it returns an exit code, a struct and which keys, or nothing.
- Put a `/** ... */` block on the class too: what it is for and the commands or classes it works with.
- Keep the `//` comments for the *why* inside a function. The DocBox block says what the function is; it is not a place for notes to yourself.
- Tests (`*.bxs`) and generated classes are exempt; helper closures need no block.

The existing code is being brought up to this rule in one pass of its own (a docs PR). Until then, do not leave a function you add or change without its block.
