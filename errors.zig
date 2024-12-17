pub const std = @import("std");
pub const Token = @import("tokenizer.zig").Token;

pub const TokenIndex = u32;
pub const Error = struct {
    pos: TokenIndex,
    end: TokenIndex,
    tag: Tag,

    pub const Tag = union(enum) {
        // Every single error which can happen.̈́
        capital_letter_in_identifier, // "Write [insert lowercase version] instead."
        character_in_identifier, // "Characters [insert invalid characters] are not allowed."
        number_identifier, // "Names cannot be numbers. Replace [insert number name] with a name of your choice."
        number_at_start_of_identifier, // "Numbers are not allowed at the beginning of a name. You could write [insert example with number at end instead] instead."
        boolean_operators: u3, // "crust does not use [insert used oeprators]. Use the keywords instead [example with keywords]"
        bitwise_operators: u3, // "crust does not use [insert used operators]. Use the functions instead [example with functions]"
        ambiguous_boolean: usize, // "Add parenthesis to clarify. Currently there are [usize] interpretations. Here are some examples: [insert interpretations examples. 1..5 examples should be enough]"
    };
};

// So, I've thought a lot about how to handle errors.
//
// I don't want to split them up into different sections of error handling
// where the next one is blocked by a previous stages errors like zig does.
//
// It would be nice to just find all error in a single function and show that
// to the user. That's what I'm planning to do here.
//
// So, the idea is. Go through all tokens and find every single error. Add
// them to a list and return them. If there are no errors, we know we can
// proceed with compilation without error handling.

// So, first we only check the syntax.
// Then we check if all identifiers are defined.
// Then we check that all types are correct.
// Then we let the borrow check do it's work.
//
// All of these are always done no matter what. one of these
// failing does not stop the next one from running. that would be
// really annoying.
//

// Ok. I am just now realizing how stupid this idea is. Even if I do it this
// way I'm going to have to decide how to parse faulty syntax. That's the actual
// hard part about this. And this method does not change that.

// The idea now is that I need to declare for each error, how to proceed with the parsing.
//
// For example. If the return type of a function has faulty syntax, we probably shouldn't
// type check it in other parts of the code. In some cases however. it would make sense to
// assume a return type. For example if a user wrote void or if a user wrote i32, i32. The
// compiler first giving an error asking you to fix that and then immidietly complaining
// about the type makes the compiler look really dumb.
//
// This is really hard, because I'm literally parsing a different language. A faulty version
// of my own language. Not only that, this language is not specified like my own, so there is
// by definition ambiguity in the interpretation.
//
// My only hope is to keep things as simple as possible.
//
// So. When a part has errors, any errors that depend on that being correct should not
// be run.
//
// Or should they? I dunno, that seems really weird, because I'm literally parsing a
// different language.
//
// It would be easy to do however in situations where parameter order is swapped. Or
// if a user adds a colon between parameters. In those specific cases it could be done.
// Is it worth it though? I just find it so annoying when fixing one error, only to
// then immideatly be greated by a new one previously hidden from me.
//
// So, in errors where I'm confident I know what the user means I can simply parse
// the faulty syntax as if it's correct and check for more errors. The compiler should
// not compile the code. The only reason is that this way I can be much more helpful to
// people getting errors.
//
// For example. Let's say I wrote "x = y && x = z || z = w". The parser should first see
// that "||" and "&&" are faulty versions of the keywords "or"/"and". However, it should
// also be able to see that this boolean statement is ambiguous. The output to the user
// should be:
//
// The operator "&&" and "||" are invalid. Instead of:
//  "x = y && x = z || z = w"
// Write:
//  "x = y and x = z or z = w"
//
// You also need to add parenthesis. Currently the statement has
// 2 interpretations. It could be interpreted as either:
//  "x = y and (x = z or z = w)"
//  or
//  "(x = y and x = z) or z = w"
//
// First getting the error about "||" and "&&" and fixing it only to be greated by the
// second error immediatly afterwards is very frustrating. That's why I want to do it
// this way.
//
// The most compelling argument against this is that a single error at a time is easier
// to digest. However, Spending minutes going back and forth between compiling and
// writing code one error at a time is quite frustrating, I don't want to replicate that.
//
// Some errors are to ambiguous to proceed. So this is handled on a case by case basis.
// For example
//
// The compiler should never compile the code if there are any errors. Even though a user
// users "||" instead of "or" which we could compile easily. Why? To keep the language
// consistent. Otherwise looking at a piece of crust code whould be similar in difficulty
// to looking at a piece of rust, c++ or javascript code. Lot's of ways to do the same
// thing and lots of weird syntax features you've never seen before.
