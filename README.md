“If I had asked my customers what they wanted they would have said a simpler rust.” - Henry Ford

# cb
The simplicity of c with the memory safety of rust.

# Main goals of cb
1. simplicity
2. friendliness
3. low level of abstraction
4. no hidden control flows

cb tries to stay as close to assembly code as possible. This is why it handles scope in an unconventional way and why there is only one `loop` keyword. This makes the syntax simple and the language fast both in execution and compilation.

The most important abstraction from assembly code is memory management. cb uses a borrow checker similiar to rust for this. However, because of cb's simplicity **there are no lifetimes** and the borrow checker is much simpler.

In general, cb's goal is to be as low level and simple as possible while still being a powerful tool. Similar to c, but even simpler and with a few modern features.

The compiler is by design incredibly simple and the assembly code generated is mostly readable. I have strayed away from implementing too many optimisations in order to keep it this way.

I believe it is important for a developer to understand his own tools. cb is designed in a way to be as understandable as possible. The abstraction cb does on assembly is not as big as one might think.

The simplicity of cb also enables better error messages. There are not a lot of possible errors in cb. The first one you're probably going to run into is either `error: cb is one-indexed` or `error: cb expected indentation here`.
# Game programming
cb has first class support for game development.
## Graphics programming
cb natively supports graphics programming in [webgpu](https://en.wikipedia.org/wiki/WebGPU). As mentioned below, cb compiles to webassembly code for compatibility and this plays nicely with webgpu which is meant to be used in the browser. The builtin ... is called

Working with webgpu in other languages can be a massive pain. You need to redefine your types, you need to memorize numbers since shader language doesn't have enums. Etc. cb interacts with webgpu in a very convenient way, the languages are not too dissimilar though to be fair.
## Networking
cb natively supports websockets for easy multiplayer implementations. The builtin ... is called.
## Audio
bla bla
## Input handling
bla bla
# Lsp
Remember what you dislike about zls.
# Compiler
cb compiles to webassembly code for compatibility. The `-r` flag uses your browser to run the webassembly code. When graphics programming is used or javascript is otherwise required cb will generate the necessary html and javascript in a file called `index.html`. Start your program after compiling it by running `$ cb -s` which starts a webserver for your program and opens it in a new tab.

Helpful and friendly errors. Include values when relevant. Don't let the conventional structure of a compiler stop you from implementing friendlier errors. Also, don't make a conventional compiler. Thas boring as hell and also very limiting. Also, it's not really necessary for this language and would just cause unnecessary overhead and worse compilation times.
## Command line interface
The errors from either the compiler or parser will have color end text formating woth Ansi escape codes. as well as file, line and column number in a clickable link (I do not know if this works with neovim). A image of the location of the error woth underlining of the specific part of the line with the error is also shown. Runtime errors should idealy be formatted in a nice way, however the stacktrace could make that difficult.

### Command line flags
The avaliable command line flags are
```
$ cb program.cb       Compile
$ cb program.cb -r    Run
$ cb program.cb -t    Test
$ cb -s
```
# Parser
indentation parsing from python.
# Undefined
You can declare a variable without giving it a value. However, if the variable is used before getting a value a runtime error occurs. Think of it as a pinky promise that you will give the variable a value before using it:
```
int number

number = 2
print(number)
```
just like zig. cb will set all undefined bytes to hexadecimal `0xaa` or `10101010` in binary. This is for debuggng puropses and only works when running the program directly, that is `$ cb program.cb -r`. The `-r` flag means to run the program.
# Comptime
Any expression that is known at compile time can be evaluated at compile time using the `comptime` keyword. This functionality is borrowed from zig.

Any expressiom that would normaly require error handling that is compile time known can omit the error handling. The compiler will throw an error if the expression is evaluated to be an error.
# Try
`try function()` is syntax sugar for the code block:
```
function() catch error
  return error
```
With the `try` keyword you are propagating the error to another function. This is a quick and dirty way to handle errors. Generally, you should use `catch` and `switch` if you want to handle errors properly.

# Error handling
cb handles errors like values. To declare a function that can return an error, use the `!` operator. `!uint function(int number)` `my_error!uint function(int number)`. This is that same syntax as zig. The syntax for catching errors is also similar:
```
x = function("1234567890") catch error
  Handle the error here:
  ...
```
And with a switch statement:
```
x = function("1234567890") catch error switch error
  my_error.type1 => Do something.
  my_error.type2 =>
    Do something on
    multiple lines.
  my_error.type3 => Do something.
  _ => Default case.
```
Which can be simplified with some syntax sugar:
```
x = function("1234567890") switch error
  my_error.type1 => Do something.
  ...
  _ => Default case.
```
The reason for this syntax sugar is that you're going to be switching on errors a lot in cb. The compiler checks that you have covered all possibilites in your switch statement.
# Tests
cb has the keyword `test` for implementing tests in programs. Write `test` and the start of a line and write the boolean statement you want to test: `test x + y > 1`. If said test fails cb will show you the values of the variables
```
testing filename.cb...
  5 | passed!
  9 | passed!
  13 | failed at file://filename.cb:13
    x + y > 1 is false because 0 + 1 > 1 is false
  20 | passed!
```
cb tests sequentially and doesn't stop upon failure.
# Strings
Strings are handled as arrays or slices of bytes. That is `array20_u8` or `slice_u8`.

# Arrays
Arrays are statically sized lists of values. This means that both the type it contains and the array itself needs to have a known size at compile time. The array is simply stored as a pointer to the first element and a length.

# No main function
There are no main functions in cb. Just write your code in the top level.

# Command line arguments
to access command line arguments in cb you use the builtin constant `argv `.

# Loops
cb has one loop keyword. This loops forever:
```
loop
  ...
```
These are for loops:
```
loop numbers as num
  ...
```
```
loop 1..10 as i
  ...
```
This is equivalent to a while loop:
```
loop
  break if ...
```
# Mutability
Everything is immutable by default. Make something mutable with the `mut` keyword: `mut int x = 5`;
# Types
cb is a statically typed language. You always have to give a variable a type.
# Indexing
Index a slice, list or array with the syntax `array[1]`. Please note that cb is one indexed. Cry about it. Arrays which are statically sized are bounds checked at compile time and don't need any error handling. However, slices or lists with unknown size require error handling. (Unless you're writing index 0 in which it's still a compiler error: `Error: cb is one-indexed.`). If you're not meaning to do proper error handling, then just use the `try` keyword like so `try slice[1]`. If you want proper error handling of out of bounds and such you'd use the `catch` or `switch` keyword as explained in their appropriet headers above.
### Why one-indexed?
Are you seriously going to tell me that getting the 5th element by writing `array[4]` is intuitive? Or that getting the first 5 elements by typing `array[0..4]` is intuitive? Do you seriously, with a straight face, say that zero-indexing is the most intuitive for beginners. Zero-indexing has forced every programming course to warn newcommers that programming is zero indexed beacuse the beginner would rightfully assume it to be one-indexed like any sane language designed for humans. Give me one good reason for zero-indexing that is not because it is the convention. The only reason we still use it is because we're too lazy to change it.
# Explicit error handling
You always need to handle errors. No matter what the operation is. Indexing (unless it's an array) can return an error after a bounds check. An arithmetic expression can be undefined (not as in the `undefined` keyword but as in division by zero for example). An arithmetic operation can overflow etc... cb forces you to always handle these errors no matter what. To skip writing proper error handling, write `try` before the operation: `try a - b * 9`. Don't forget to declare your function as an error union `!void function()`.
# Scope
Scope in cb is a bit wierd. There are only two scopes. Function scope and Gobal scope. This might take some getting used to for seasoned developers. Beginners will probably have an easier time though. The reason for this desogn decision is to make the borrow checker and language simpler. This means that:
```
if true
  x = 2
print(x)
```
Is valid cb code.
# Pointers
Pointer syntax is `*variable`. Dereference the pointer by removing the asterix `variable`. This is weird syntax compared to other languages. However I find it to be less ambiguous. now you can always be sure that an asterix before an identifier means it's a pointer and that nothing else can be a pointer. This also means that you cannot store a pointer in another variable. There is no pointer datatype. The only way to use a pointer is as a function argument. This makes the borrow checker simpler which is important for this language.

Pointers are immutable and the value they point to is immutable by default. Add the `mut` keyword to make the value behind the pointer mutable.
# Memory management
cb handles memory management through a borrow checker [similar to rust](https://rustc-dev-guide.rust-lang.org/borrow_check.html). But before you get scared and run away, please note that cb's borrow checkear is simplier than rusts. cb's borrow checker does not have lifetimes and it only enforces a simple set of rules:
- You cannot use a moved variable
- You can not have a immutable reference while having a mutable reference
- ...
