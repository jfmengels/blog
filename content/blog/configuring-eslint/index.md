---
title: Configuring ESLint like elm-review
date: '2021-06-15T12:00:00.000Z'
---

TODO Rename to re-configure? Or something that mentions "ESLint's configuration system", like "ESLint's configuration system à la elm-review"

TODO Mention explicitness, and composition over inheritance?

I have used `ESLint` extensively in the past. As a user, as the "ESLint configurator" for my teams, and as a rule author.

Since then, I have had even more experience designing and creating my own static analysis tool for the [`Elm` language](https://elm-lang.org/) named [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/), which was heavily inspired by my years of working with `ESLint`.

I was curious to see how the configuration for `ESLint` would look like if it used the same ideas `elm-review` uses, and
created a small example API. I believe it allows for more fine-grained control configuration and a more intuitive configuration experience.

This proposal was shaped on my personal views on static analysis tools, some of which can be found in
[_how disable comments make static analysis tools worse_](/disable-comments). Reading that article will definitely help
understand my maybe controversial opinions, while reading this current article will show how they can be set in place.

## Current configuration

Following is a sample of how the configuration for `ESLint` looks like at the time of writing (June 2021).
I will not try to replicate it, but I just wanted to add a reminder.
This file can be written either as a JavaScript file (as below) or as a JSON file (slightly different but very close).

```js
module.exports = {
    "env": {
        "es2021": true,
        "node": true
    },
    "extends": [
        "eslint:recommended",
        "plugin:react/recommended"
    ],
    "parserOptions": {
        "ecmaFeatures": {
            "jsx": true
        },
        "ecmaVersion": 12,
        "sourceType": "module"
    },
    "plugins": [
        "react"
    ],
    "rules": {
        "indent": [ "error", 4 ],
        "linebreak-style": [ "error", "unix" ],
        "quotes": [ "error", "double" ],
        "semi": [ "error", "always" ]
    }
};
```

There is ongoing work to re-design the configuration system, and you can find the RFC for that [over here](https://github.com/eslint/rfcs/tree/main/designs/2019-config-simplification).


## The idea

`elm-review`'s configuration is done through a file written in Elm, so `ESLint`'s should be done in a JavaScript file.
This way, the configuration can be manipulated more easily by the users of the tool because it's done in a written in a
language that they're already familiar with.

That is not a big departure from the current system since that is already supported, and in the next re-design it will be the only solution anyway.

I believe that this works well when the configuration is fast to load, meaning that it works well for "scripted" languages
like JavaScript or Python, as well as compiled languages where the compilation is very fast and easy to set up (like Elm).
It becomes increasingly cumbersome in the other cases. So let's consider us lucky we're in this situation!


```js
import /* ... */;

const rules = /* ... */;

export default {
  languageOptions: {
    ecmaVersion: 2020,
    sourceType: "module"
  },
  rules: rules
  // ... other options
};
```

The exposed configuration would be done through the `export default` syntax, or `module.exports`, or a named export, it doesn't really matter too much.
A decision would need to be made, but whichever is used is fine and won't matter for the rest of the proposal.

The options in that object would be close to what is currently in there. My knowledge on the available top-level options has grown smaller,
but it will likely remain mostly unchanged, except for options like `"plugins"` and `"rules"` which we'll focus on.
Maybe the others need to be rethought as well, but I have nothing to bring to the table on that subject.

The interesting change is in `rules`, which has become an array. If you want to enable a specific rule, for instance one of the core `ESLint` rules, add it to the array.

```js
import * as core from "eslint";

const rules = [
  core.noUnusedVars(),
  // more rules...
];
```

Possibly, the rule would be exposed as `core["no-unused-vars"]`. It's not as nice in my opinion, but that would probably
be the better option for better backwards compatibility and consistency with the current naming convention.
I hope you don't mind, but I'll stick with the camel case version though.

In `elm-review`, the whole configuration is just this list of rules. We currently have no need for additional
configuration because Elm is a simpler language and ecosystem than JavaScript, and we can infer all the information we
need from project files.

---

If you want to extend a configuration, use JavaScript spread or concatenation:

```js
import * as core from "eslint";

const rules = [
  ...core.recommended,
  // more rules...
];
```

`core.recommended` and other configurations would just be arrays of rules (Note that this is maybe simplified for configurations from plugins).

If you want to disable a rule because you want to turn it off or use different configuration, remove it with a JavaScript `.filter()` call:

```js
const rules = [
  ...core.recommended.filter(rule => rule.name !== "no-console"),
  // more rules...
];
```

TODO Mention it's not a good idea?

---

Notice that `core.noUnusedVars` was a function? That's because options would be moved to be simple arguments of each rule.

That would make configuration a bit more straightforward for rule authors to extract from the context, and allows
functions, regexes and other non-JSON values to be passed as configuration. Also, you can now potentially validate a configuration using TypeScript.

```js
const rules = [
  core.noUnusedVars(),
  core.noConsole({ "allow": ["warn", "error"] }),
  // more rules...
];
```

We could choose to have `core.noUnusedVars` to not be a function, but then users would have to know which rules take arguments and which don't, which I think would make for a worse experience.

I think that some would probably advise for allowing both, as I often see it in the JavaScript world. "If it looks like a rule, treat it as a rule. If it's a function, call it with no arguments" (`ESLint`'s next configuration does this with arrays of settings I believe).

While that would work, I'd advise against it because it makes the configuration less consistent, and would add more baggage to the tool that could one day prove to be problematic.

**Consistency is a form of TODO???.**

Instead, have `ESLint` report a nice and detailed configuration error when one element does not look like a rule, and everyone will be better off.
Otherwise I'm sure some people would be inclined to create `ESLint` rules to make the `ESLint` configuration fit their preferences.

---

How would plugins work? Plugins are essentially (well, mostly) packages that export rules and sometimes pre-defined configurations. So if we took
the plugin for React, using the rules could look like:

```js
import * as react from "eslint-plugin-react";

const rules = [
  react.forbidPropTypes(),
  // more rules...
];
```

Depending on the structure of the package, the way to access the rules could be slightly different (such as
`react.rules["forbid-prop-types"]`), but it could still be close to this. For plugins that simply add rules like
`eslint-plugin-react` (and not change the behavior of `ESLint` somehow), there would be no need to add it to a list of
plugins like is done currently **and** add it to the list of rules.

Configuration would feel a lot less "magic". It becomes much easier to figure out how the configuration messed up when
it happens. If someone types `react.frbidPropTypes()`, there will be stack trace that hopefully will be helpful enough
to figure out the issue.

I think that the current behavior of reporting an error in every file is sub-par, though I guess there are some reasons
for that I'm not aware of.

Similarly, I believe that if a rule is misconfigured, it should be able to gracefully report it to `ESLint` who would
then show a nice error message to the user that says that a rule was misconfigured, and preventing further usage until
the usage has been solved.

Overall, learning to configure `ESLint` will be a lot closer to learning JavaScript than learning a new tool, just like
when we filter rules or concatenate rule arrays.


## Rule specific configuration

Here comes the—in my opinion—interesting part: general rule-specific configuration.

After being passed arguments, every rule can be configured further through chained method calls.

For instance, notice that we didn't specify the severity of the rule so far. We would do that by chaining a method call on the rule:

```js
core.noUnusesVars()
    .asWarning()
```

Rules would have to be wrapped in some kind of construct, so rule authors would have to expose the result of a function
call of a function that `ESLint` provides, instead of an object with `meta` and `create` keys.

```js
function noConsole(options) {
  return core.createRule({
    meta: { /* meta */ },
    create: function create(context) {
      // forbid console the same way that is currently done
    }
  });
}
```

Note: in this example, arguments passed to the rule would show up as arguments of the `noConsole` function. They would
then be available through a closure in the `create` function.

`ESLint` would be the one to add and maintain methods like `asWarning` above, not rule authors. To work well,
rules would need to be immutable, meaning every method call would return a new copy of the rule that would have this additional configuration.

Back to warnings explicitly. Rules would be errors by default, since [warnings are actually detrimental to a project](/disable-comments#warnings).
`elm-review` doesn't have severity levels at all.

Similarly, we could have an opt-in option to allow disabling a rule with a comment like `// eslint-disable-line`.

```js
core.noUnusesVars()
    .allowDisableComments()
```

I believe that this [should not be allowed by default](/disable-comments#non-disableable-rules-by-default), and again,
it's a feature that `elm-review` doesn't have.


---

We can also use this construct to specify on which files a rule should or should not be run.


```js
core.noUnusesVars()
    .ignoreInDirectories(["tests/"]) // Disable on entire folders
	.ignoreInFiles(["lib/some-vendored-file.js"]) // Disable on entire files
	.ignoreIn(["lib/**/*.ts"]) // Disable using regexes (for compatibility with current features)
```


I believe this allows for more fine-grained control of when a rule would be enabled or not. This should remove the need
for disable comments at the top of a file, and move all or most of the knowledge of what is ignored and disabled to the configuration
file(s).

`elm-review` only has the [directories](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#ignoreErrorsForDirectories)
and the [files](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#ignoreErrorsForFiles) variants,
not the regex one, due to a lack of need for it at the moment.

There could also be a `.onlyInDirectories([...])` and similar variants, which `elm-review` has not felt the need for yet.
Someone would have to choose what happens when both `onlyIn...` and `ignoreIn...` variants are used together in contradictory ways though.

If you need to disable several rules for a specific part of the project, you can use the language and create a helper function:

```js
const rules = [
	ruleEnforcedInTests(),
	
	notForTests(rule1()),
	notForTests(rule2()),
	
	...aLotOfRulesToBeIgnoredInTests.map(notForTests),
	// more rules...
];

function notForTests(rule) {
	return rule.ignoreInDirectories(["tests/"]);
}
```

---

These modifiers can be applied on the rules themselves. So if you were writing a custom rule for your application, you could do something like

```js
function noHttpCallsExceptIn(filePaths) {
  return core.createRule({
    meta: { /* meta */ },
    create: function(context) {
      // somehow forbid any HTTP call or imports
    }
  }).ignoreInFiles(filePaths);
}

const rules = [
	noHttpCallsExceptIn("src/http.js")
];
```

---


Since we're not using an object with the rule name as the key, we can now have duplicate rules.
When designing elm-review, I tried making it impossible to have duplicate rules. In the end, I noticed that it could actually be useful and therefore allowed it.

One instance where this is useful is when you want the same rule configured differently for different parts of the project.

```js
const rules = [
  someRule({ allowUnsafeOperations: true })
	.onlyInDirectories(["legacy-codebase/"]),

  someRule({ allowUnsafeOperations: false })
	.ignoreInDirectories(["legacy-codebase/"]),
];
```

Another one is to allow to use a rule like [`no-restricted-syntax`](https://eslint.org/docs/rules/no-restricted-syntax), which is very useful
rule, but as far as I know can't be composed. If you inherit from 2 configurations that both use this rule, only one of them gets used and the other one gets silently ignored.

```js
const rules = [
  core.noRestrictedSyntax(["WithStatement"]),
  core.noRestrictedSyntax(["CallExpression[callee.name='setTimeout']"])
];
```

## Overview

Here's what a full `ESLint` configuration could look like:


```js
import * as core from "eslint";
import * as react from "eslint-plugin-react";

const rules = [
  ...core.recommended.filter(rule => rule.name !== "no-console"),

  core.noUnusedVars(),
  core.noConsole({ "allow": ["warn", "error"] }),
  core.noRestrictedSyntax(["WithStatement"]).ignoreInDirectories(["tests/"]),
  core.noRestrictedSyntax(["CallExpression[callee.name='setTimeout']"]),

  react.forbidPropTypes().ignoreInDirectories(["backend/"]),

  someNonImportantRule().asWarning(),
].map(rule => rule.ignoreInDirectories(["generated-code/"]));

export default {
  languageOptions: {
    ecmaVersion: 2020,
    sourceType: "module"
  },
  rules: rules
};
```

To recap: rules are functions that takes options as arguments and return immutable values that can be chained to alter the way `ESLint` runs them.


Benefits:
1. Control over the configuration becomes a lot more fine-grained, which should reduce the number of `eslint-disable` comments in the project
1. Rules can easily be duplicated (for `no-restricted-syntax` or rules with different configuration for different parts of the codebase)
1. The rule configuration comes from JavaScript arguments, not data that authors have to extract from the "context". You could even validate this using TypeScript!
1. Configuration is very explicit and a lot less magic, as there is no magic references to ESLint plugins. It becomes much easier to figure out how the configuration works or got messed up. If someone types `react.frbidPropTypes()`, the error message should be a lot clearer than currently. Overall, learning to configure `ESLint` will be a lot closer to learning JavaScript than learning a new tool.
1. A shareable `ESLint` configuration is now mostly a simple array of pre-configured rules
1. Since rules don't have to be loaded through the current system, no need for `--rulesdir` to define custom rules for your application/package: just import the file and add the rule to `rules`. I hope this would lower the barrier to locally forking an `ESLint` rule even more (instead of users demanding maintainers for more options to have a rule fit their unique preferences), and push people towards creating their own custom rules even more, which is such an amazing tool to have at your disposal.
1. I believe that the configuration of rules is a lot more straightforward like this, compared to the complex merge system that needs to be taught to users and the magic numbers/strings (`2`/`"error"`).

A few downsides that I can see:
1. This is obviously a breaking change. All `ESLint` plugins would need to be re-published and to use the new way to create a function. But I think it would be possible to have a helper function to transform the old version to the suggested API. Users could even maybe wrap existing rules in the `core.createRule` themselves if maintainers aren't responding).
1. It will not be possible (or very hard?) to re-define the options for a rule using directive comments like `/* eslint quotes: ["error", "double"] */`. I personally don't see this as a downside, but this is an existing feature that people might use.
1. Compared to JSON/YAML, it becomes a lot harder to programmatically add a new rule to the configuration, with a command like `eslint add-rule no-unused-vars`. `ESLint` doesn't support that anyway at the moment.
1. While shareable configurations would mostly be arrays of rules, overriding something from that configuration (turning off, changing the options, ...) is harder than it currently is. While I don't think these configurations are all that good for people who tend to their configuration anyway, they are very practical to get started. I guess I still prefer copy-pastes of configurations. But since shared configurations are quite **core to the ESLint ecosystem**, this is likely the biggest downside of the proposal as it is right now.

## elm-review

For those interested, this is what an `elm-review` configuration looks like:

```elm
module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import Documentation.ReadmeLinksPointToCurrentVersion
import NoDebug.Log
import NoDebug.TodoOrToString
import NoExposingEverything
import NoForbiddenWords
import NoImportingEverything
import NoMissingTypeAnnotation
import NoMissingTypeAnnotationInLetIn
import NoMissingTypeExpose
import NoUnused.CustomTypeConstructorArgs
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Review.Rule as Rule exposing (Rule)
import Simplify


config : List Rule
config =
    [ Documentation.ReadmeLinksPointToCurrentVersion.rule
    , NoDebug.Log.rule
    , NoDebug.TodoOrToString.rule
        |> Rule.ignoreErrorsForDirectories [ "tests/" ]
    , NoExposingEverything.rule
    , NoForbiddenWords.rule [ "TODO" ]
    , NoImportingEverything.rule []
    , Simplify.rule Simplify.defaults
    , NoMissingTypeAnnotation.rule
    , NoMissingTypeAnnotationInLetIn.rule
    , NoMissingTypeExpose.rule
    , NoUnused.CustomTypeConstructors.rule []
    , NoUnused.CustomTypeConstructorArgs.rule
    , NoUnused.Dependencies.rule
    , NoUnused.Exports.rule
    , NoUnused.Modules.rule
    , NoUnused.Parameters.rule
    , NoUnused.Patterns.rule
    , NoUnused.Variables.rule
    ]
    |> List.map (Rule.ignoreErrorsForDirectories [ "generated-src/" ])
```

Pretty similar, right?!

At the moment, there is only the equivalent of `ESLint`'s `rules`. There is no other option the tool takes or information that the tool can't infer from other project files. For now, this has worked really well.

This configuration file gets compiled by the Elm compiler, so almost all configuration errors are turned into compiler errors, and if you know Elm, you know that the error messages are really helpful. And `elm-review`'s messages and the rules' error messages follow that trend as well.


## Afterword

I hope you found this design interesting!

I spent a lot of time using, configuring and writing rules for `ESLint` and it definitely inspired `elm-review`, though [the end results are quite different](https://gist.github.com/jfmengels/111defdc980926ce472a4a0f8f8b5123). I can confirm that this configuration system has worked really well for `elm-review`!

`ESLint` has a huge ecosystem to support, different constraints than `elm-review` and already a re-design of the
[configuration system in the works](https://github.com/eslint/rfcs/blob/main/designs/2019-config-simplification/README.md).
While I think the new design is an improvement to the current, I also *personally* feel like it is not as good as this one.
Ultimately it's a matter of trade-offs (in both ways!) and balancing these to fit `ESLint`'s goals best.

Making such important decisions should not be taken lightly, and even if you think my design is nice, I have potentially skipped over some important details, like additional configuration not directly related to a rule that could still have an impact on it, or the fact that configurations in plugins contain more than just rules.

I will not create an official RFC for it, as I am not heavily writing JavaScript nor TypeScript at the moment (Join the [Elm](https://guide.elm-lang.org/) side!) and I'm already spending all of my spare time working on `elm-review`.

I hope that people involved in that project will try to take what they think are good ideas and integrate them into the tool, so that both tools become better. I will keep following how `ESLint` evolves as usual.



TODO Remove this next part

```js
import * as core from "eslint";
// Import your list of plugins/configs
import * as react from "eslint-plugin-react";

let rules = [
  // Enable a single rule
  core.noUnusedVars(), // Possibly also exposed as `core["no-unused-vars"]()` which would be more consistent with the current naming
  
  // Use all the rules from some configuration (which would be an Array of rules)
  ...core.recommended
    // Remove rules that you want to override or to turn off
    .filter(rule => rule.name !== "no-console"),

  // Enable a rule from a plugin
  react.forbidPropTypes(),

  // Enable a rule with options
  core.noConsole({ "allow": ["warn", "error"] }),
  
  // With rule-specific configuration
  core.someOtherRule()
    // Rules are errors by default, since warnings are not great (elm-review doesn't have them)
    // https://github.com/jfmengels/elm-review/blob/2.4.2/documentation/design/severity-levels.md
    .asWarning() // Alternatively `.withSeverity("warn")`

    // Allow disabling this rule through comments like "eslint-disable-line", make this not be the default.
	.allowDisableComments()

	// "The team agrees to not enforce this specific rule in tests"
	.ignoreInDirectories(["tests/"])
	.ignoreInFiles(["lib/some-vendored-file.js"])
	.ignoreIn(["lib/**/*.ts"]), // using regex

  // Enable the same rule with two different options on different parts of the codebase
  core.noRestrictedSyntax(["WithStatement"])
	.ignoreInDirectories(["tests/"]),

  core.noRestrictedSyntax(["WithStatement", "CallExpression[callee.name='setTimeout']"])
	// Note that we haven't needed to have these "onlyIn*" variants with elm-review
	.onlyInDirectories(["tests/"]),
];

/* If we wanted to ignore some files for ALL rules, we could do something like the following
*/
rules = rules.map(rule => rule.ignoreInDirectories(["generated-code/"]));
// Same thing for other transformations, like making them be warnings.

// Expose the whole configuration. I don't know what all the available options are,
// But potentially we could have a similar looking API for this.

export default {
  languageOptions: {
    ecmaVersion: 2020,
    sourceType: "module"
  },
  rules: rules
  // ... other options
};
```