---
title: Configuring ESLint like elm-review
date: '2021-06-15T12:00:00.000Z'
---

# Configuring ESLint like elm-review

I have used `ESLint` extensively in the past. As a user, as the "ESLint configurator" for my teams, and as a rule author.

Since then, I have had even more experience designing and creating my own static analysis tool for the [`Elm` language](https://elm-lang.org/) named [`elm-review`](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/), which was heavily inspired by my years of working with `ESLint`.

I was curious to see how the configuration for `ESLint` would look like if it used the same ideas `elm-review` uses, and created a small example API. I believe it allows for more fine-grained control configuration and a more intuitive configuration experience.

TODO Show current
TODO Explore how to do rules for certain folders. Explore what "files" does.
TODO Allow rules to report configuration errors when the passed options are unexpected. Don't let the rule run with invalid premises.
TODO Mention it works well when the configuration is fast to load, so either a dynamic language or a language with very fast compile times (like Elm).

## Current configuration

TODO Following is a sample of how the configuration for `ESLint` looks like. I will not try to replicate it, but I just wanted to add a reminder.

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

## The idea

First of all, `elm-review`'s configuration is done through a file written in Elm, so `ESLint`'s should be done in a JavaScript file. That is not a big departure for the current system since that is already supported, and in the next major version will be the only solution anyway.

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

The exposed configuration would be done through this syntax, or `module.exports`, or a named export, it doesn't really matter too much.
The options in that object would be close to what is currently in there. My knowledge on the available top-level options has grown smaller,
but it will likely remain mostly unchanged, except for options like `"files"` and "`rules`". Maybe it could be rethought as well, but this is not what I have focused on.

The interesting change is in `rules`, which has become an array. If you want to enable a specific rule, for instance one of the core `ESLint` rules, add it to the array.

```js
import * as core from "eslint";

const rules = [
  core.noUnusedVars(),
  // more rules...
];
```

Possibly, the rule would be exposed as `core["no-unused-vars"]()`. It's not as nice in my opinion, but that would probably be the better option for better backwards compatibility and consistency with the current naming convention. I'll stick with the camel case for now though.

In `elm-review`, the whole configuration is just this list of rules. We currently have no need for additional configuration because Elm is a simpler language and ecosystem than JavaScript, and we can infer all the information we need from project files.

---

If you want to extend a configuration, use JavaScript spread or concatenation:

```js
import * as core from "eslint";

const rules = [
  ...core.recommended,
  // more rules...
];
```

`core.recommended` and other configurations would just be an array of rules (Note that this is maybe simplified for configurations from plugins).

If you want to disable a rule because you want to turn it off or use different configuration, remove it with a JavaScript `.filter()` call:

```js
const rules = [
  ...core.recommended.filter(rule => rule.name !== "no-console"),
  // more rules...
];
```

---

Notice that `core.noUnusedVars` was a function? That's because options would be moved to be simple arguments of each rule. That would
make configuration a bit more straightforward for rule authors to extract from the context. Also, you can now potentially validate
a configuration using TypeScript.

```js
const rules = [
  core.noUnusedVars(),
  core.noConsole({ "allow": ["warn", "error"] }),
  // more rules...
];
```

We could choose to have `core.noUnusedVars` to not be a function, but then users would have to know which rules take arguments and which don't, which I think would make for a worse experience.

I think that some would probably advise for allowing both, as I often see it in the JavaScript world. "If it looks like a rule, treat it as a rule. If it's a function, call it with no arguments" (`ESLint`'s next configuration does this with arrays of settings I believe).

While that would work, I'd advise against it because it makes the configuration less consistent, and would add more baggage to the tool that one day might be hard to support with backwards-compatibility.

Instead, have `ESLint` report a  nice and detailed configuration error when one element does not look like a rule, and everyone will be better off. Otherwise I'm sure some people would be inclined to create `ESLint` rules to make the `ESLint` configuration fit their preferences.

---

How would plugins work? Plugins are essentially (well, mostly) packages that export rules and sometimes configurations. So if we took
the plugin for React, using the rules could look like:

```js
import * as react from "eslint-plugin-react";

const rules = [
  react.forbidPropTypes(),
  // more rules...
];
```

Dependending on the structure of the package, the way to access the rules could be slightly different (such as `react.rules["forbid-prop-types"]`), but it could still be close to this. For plugins that simply add rules like `eslint-plugin-react` (and not change the behavior of `ESLint` somehow), there would be no need to add it to a list of plugins like is done currently **and** add it to the list of rules.

Configuration would feel a lot less "magic". It becomes much easier to figure out how the configuration messed up when it happens. If someone types `react.frbidPropTypes()`, the error message will be a lot clearer than currently. Overall, learning to configure `ESLint` will be a lot closer to learning JavaScript than learning a new tool, just like when we filter rules or concatenate rule arrays.


---


Rule specific configuration

Here comes the—in my opinion—interesting part: rule-specific configuration. After being passed arguments, every rule can be configured further through chained calls.

For instance, notice that we didn't specify the severity of the rule so far. We would do that by chaining a method call on the rule:

```js
core.noUnusesVars()
    .asWarning()
```


Rules would have to be wrapped in some kind of construct, so rule authors would have to expose the result of a function call of a function that `ESLint` provides, instead of an object with `meta` and `¢reate` keys. Then `ESLint` would be the one to add and maintain properties like `asWarning` above, not rule author. To work well, rules would need to be immutable, so every function call would return a new copy of the rule that would have this additional configuration.

Back to warnings explicitly. Rules would be errors by default, since warnings are actually detrimental to a project. `elm-review` doesn't have severity levels, as I've described somewhere in the [design documentation](https://github.com/jfmengels/elm-review/blob/2.4.2/documentation/design/severity-levels.md).

Similarly, we could have an opt-in option to allow disabling a rule with a comment like `// eslint-disable-line`

```js
core.noUnusesVars()
    .allowDisableComments()
```

I believe that this should not be allowed by default. `elm-review` [doesn't even have this system](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/#is-there-a-way-to-ignore-an-error-or-disable-a-rule-only-in-some-locations-), and it has worked really well for us, partly because the design of the target language and its compiler make false positives a rare occurrence. TODO Link to other article.
Anyway, disable comments should not be enabled by default. Instead, rules should be improved, configured or disabled.


---

We can also use this construct to specify on which files a rule should or should not be run.


```js
core.noUnusesVars()
    .ignoreInDirectories(["tests/"]) // Disable on entire folders
	.ignoreInFiles(["lib/some-vendored-file.js"]) // Disable
	.ignoreIn(["lib/**/*.ts"]) // Disable using regexes (for backwards compatibility)
```


I believe this allows for more fine-grained control of when a rule would be enabled or not. This should remove the need
for disable comments at the top of a file, and move all the knowledge of what is ignored and disabled in the configuration file(s). Files that are ignored for a rule can be entirely skipped by `ESLint` which I imagine would remove unnecessary work (but maybe `ESLint` is doing pretty smart already).

`elm-review` only has the [directories](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#ignoreErrorsForDirectories) and the [files](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/Review-Rule#ignoreErrorsForFiles) variants, not the regex one, due to a lack of need.

There could also be a `.onlyInDirectories([...])` and similar variants, which `elm-review` has not felt the need for yet. Someone would have to choose what happens when both `onlyIn...` and `ignoreIn...` variants are used together in contradictory ways.

If you need to disable several rules for a specific part of the project, you can resort to use helper functions and `Array.map`:

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
function noHttpCallsExceptIn(filePath) {
  return core.createRule({
    meta: { /* meta */ },
    create: function(context) {
      // somehow forbid any HTTP call or imports
    }
  }).ignoreInFiles(filePath);
}

const rules = [
	noHttpCallsExceptIn("src/http.js")
];
```

---


Since we're not using an object with the rule name as the key, we can now have duplicate rules. When designing elm-review, I tried making it impossible to have duplicate rules. In the end, I noticed that it could actually be useful and therefore allowed it.

One instance where this is useful is when you want the same rule configured differently for different parts of the project.

```js
const rules = [
  someRule({ allowUnsafeOperations: true })
	.onlyInDirectories(["legacy-codebase/"]),

  someRule({ allowUnsafeOperations: false })
	.ignoreInDirectories(["rewrite-v4/"]),
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
  core.noRestrictedSyntax(["WithStatement", "CallExpression[callee.name='setTimeout']"]),

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

To recap: rules are functions that takes options as arguments and return immutable values that can be chained to alter the way the way `ESLint` runs them.


Benefits:
- Control over the configuration becomes a lot more fine-grained, which should should reduce the number of `eslint-disable` comments in the project
- Rules can easily be duplicated (for `no-restricted-syntax` or rules with different configuration for different parts of the codebase)
- The rule configuration comes from JavaScript arguments, not data that authors have to extracts from the context. You could even validate this using TypeScript!
- Configuration is very explicit and a lot less magic, as there is no magic references to ESLint plugins. It becomes much easier to figure out how the configuration works or got messed up. If someone types `react.frbidPropTypes()`, the error message should be a lot clearer than currently. Overall, learning to configure `ESLint` will be a lot closer to learning JavaScript than learning a new tool.
- A shareable `ESLint` configuration is now mostly a simple array of pre-configured rules
- Since rules don't have to be loaded through the current system, no need for `--rulesdir` to define custom rules for your application/package, just import the file and add the rule to `rules`. I hope this would lower the barrier to locally forking an `ESLint` rule even more (instead of users asking for more options to have a rule fit their unique preferences), and push people towards creating their own custom rules even more, which is such an amazing tool to have at your disposal.


A few downsides that I can see:
- This is obviously a breaking change. All `ESLint` plugins would need to be re-published and to use the new way to create a function. But I think it would be possible to have a helper function to transform the old version to the suggested API.
- It will not be possible (or very hard?) to re-define the options for a rule using directive comments like `/* eslint quotes: ["error", "double"] */`. I personally don't see this as a downside, but this is an existing feature that people might use.
- Compared to JSON/YAML, it becomes a lot harder to programmatically add a new rule to the configuration, with a command like `eslint add-rule no-unused-vars`. `ESLint` doesn't support that anyway at the moment.
- While shareable configurations would mostly be arrays of rules, overriding something from that configuration (turning off, changing the options, ...) is harder than it currently is. While I don't think these configurations are all that good for people who tend to their configuration anyway, they are very practical to get started. I guess I still prefer copy-pastes of configurations.

## elm-review

For those interested, this is what an `elm-review` configuration looks like ([link](https://github.com/jfmengels/elm-review-simplify/blob/main/review/src/ReviewConfig.elm)):

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
    , NoForbiddenWords.rule [ "REPLACEME" ]
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
```

Pretty similar, right?

At the moment, there is only the equivalent of `ESLint`'s `rules`. There is no other option the tool takes or information that the tool can't infer figure from other project files. For now, this has worked really well.

This configuration file gets compiled by the Elm compiler, so almost all configuration errors are turned into compiler errors, and if you know Elm, you know that the error messages are really helpful.


## Afterword

I hope you found this design interesting!

I spent a lot of time using, configuring and writing rules for `ESLint` and it definitely inspired `elm-review`, though the end results are quite different [as I once wrote down](https://gist.github.com/jfmengels/111defdc980926ce472a4a0f8f8b5123). I can confirm that this configuration system has worked really well for `elm-review`!

`ESLint` has a huge ecosystem to support, different constraints than `elm-review` and already a re-design of the [configuration in the works](https://github.com/eslint/rfcs/blob/main/designs/2019-config-simplification/README.md). While I think the new design is an improvement to the current, I also *personally* feel like it is not as good as this one.

Making such important decisions should not be taken lightly, and even if you think my design is nice, I have potentially skipped over some important details, like additional configuration not directly related to a rule that could still have an impact on it, or the fact that configurations in plugins contain more than just rules.

I will not create an official RFC for it, as I am not heavily writing JavaScript nor TypeScript at the moment (Join the [Elm](https://guide.elm-lang.org/) side!) and I'm already spending all of my free time working on `elm-review`.

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