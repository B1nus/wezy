# cb
“If I had asked my customers what they wanted they would have said a simpler rust.” - Henry Ford

The simplicity of c with the memory safety of rust.
# Main goals of cb
1. simplicity & friendliness
2. explicit error handling
3. memory safety
# Usage
```
$ cb program.cb       Compile
$ cb program.cb -r    Run
$ cb program.cb -t    Test
```
# Webassembly
cb compiles to webassembly and will use the [WASI api](https://wasi.dev/) for performing operations such as reading files, networking etc. WASI is not [currently implemented](#WASI) and as a temporary solution cb compiles to a web application which can be run in a browser. Use `$ cb program.cb -r` to start your program. cb will generate the necessary javascript "glue" in a file called `index.html` and start a web server.
## WASI
The Webassembly System Interface ([WASI](https://wasi.dev/)) is a set of API's to perform certain tasks in webassembly outside of a browser context. For example [reading files](https://github.com/WebAssembly/wasi-filesystem?tab=readme-ov-file#goals), [using sockets](https://github.com/WebAssembly/wasi-sockets) or [using webgpu](https://github.com/WebAssembly/wasi-webgpu?tab=readme-ov-file#introduction). The benefit of WASI and Webassembly is cross-compatilibity at near native performance. WASI is still in its early days but when the day comes cb won't have to rely on a browser.
# Game Development
## Graphics programming
cb has a module called `graphics` for interfacing with [webgl](https://en.wikipedia.org/wiki/WebGL). Include it using `load graphics`.
> [!NOTE]
> cb was intended to support webgpu but [webgpu](https://en.wikipedia.org/wiki/WebGPU) adoption is slow. The idea was to make a language with great interoperability with the webgpu api, making the painful parts of webgpu easier.
## Networking, input and audio
cb has modules the modules `network`, `input` and `audio` which you can import using the `load` keyword. cb is currently using javascript for this functionality.
> [!NOTE]
> cb was intended to use WASI instead of relying on javascript and browsers. When the WASI api is mature enough, cb will compile to a single webassembly file which can be executed with a webassembly runtime such as [wasmtime](https://wasmtime.dev/).
# Datatypes
```
int
float
byte
bool
enum
```
The `int` and `float` datatypes correspond to their respecitve types in [webassembly](https://webassembly.github.io/spec/core/syntax/types.html) (`i64` and `f64`). An `enum` can be thought of as a list of possible values a variable can have and a `bool` is a datatype with two values, `true` and `false`.
# Datastructures
cb provides three datastructures: `array`, `slice` and `struct`. To assign a string to a variable you would declare a slice of bytes `slice_byte hello = "Hello, World!"`. The reason for using a slice is to avoid having to type the length of the string manually as you would with an array.
> [!NOTE]
> Strings are slices of bytes
### Structs
A struct is a collection of attributes with a name. For example:
```
struct file
  slice_byte content
  slice_byte path
  mut bool   empty = true
```
The attributes can have a default value as shown with the attribute `empty`. All attributes are immutable by default and the keyword `mut` is used to make an attribute mutable. cb will make sure all attributes are set when a struct is instantiated at compile time, otherwise it will throw an error. Instantiate a struct with the syntax
```
file myfile = file
  content = "Hello World!"
  path = "./hello_world.txt"
```
# Lsp
Remember what you dislike about zls.
# Compiler
Helpful and friendly errors. Include values when relevant. Don't let the conventional structure of a compiler stop you from implementing friendlier errors. Also, don't make a conventional compiler. Thas boring as hell and also very limiting. Also, it's not really necessary for this language since it's quite a close abstraction from webassembly.
## Command line interface
The errors from either the compiler or parser will have color end text formatting with Ansi escape codes. as well as file, line and column number in a clickable link. An illustration of the location of the error woth underlining of the specific part of the line with the error is also shown. Runtime errors should idealy be formatted in a nice way, however the stacktrace could make that difficult.

# Parser
indentation parsing from python.
# Import/Include
Import code or a module by using the `load` keyword `load graphics`. By default this code is imported at the top level, use the `as` keyword to give the code a namespace `load graphics as graph`. The lack of strings means that you're loading an module built into cb. To load a local file you put the relative path to the file inside quotation marks `load "localfile.cb"`. cb will only allow importing files in in the current directory or any subdirectory. cb will never load files in a parent directory. This is to make codebases easier to understand.
## Downloading code from the internet
You are free to download the code in any way of your chosing. Using `$ git submodule` is a good idea.
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
cb handles errors like values. To declare a function that can return an error you use the `!` operator. `!int function(int number)` `my_error!int function(int number)`. The syntax for catching errors is the following:
```
x = function(1234) catch error
  ...
```
And with a switch statement:
```
x = function(1234) catch error switch error
  .type1 => Do something.
  .type2 =>
    Do something on
    multiple lines.
  .type3 => Do something.
  _ => Default case.
```
Which can be simplified with some syntax sugar:
```
x = function(1234) switch error
  .type1 => Do something.
  ...
  _ => Default case.
```
You're going to be switching on errors a lot in cb so this syntax sugar will be useful.
> [!NOTE]
> The compiler checks that you have covered all possibilites in your switch statement.
## Declaring an error
You declare an error as en `enum`:
```
enum my_error
  file_not_found
  out_of_memory
  too_fast
```
# Tests
Use the keyword `test` and write the boolean statement you want to test. For example `test x + y > 1`. If said test fails cb will show you the values of the variables:
```
testing filename.cb...
  5 | passed!
  9 | passed!
  13 | failed at file://filename.cb:13
    x + y > 1 is false because 0 + 1 > 1 is false
  20 | passed!
```
cb runs tests sequentially and doesn't stop upon failure.
> [!TIP]
> Try moving more complicated tests into their own file.
# Slices with known size
Slices can either have a known size or unknown size at compile time. The benefit of slices with known size is that the bounds check is performed at compile time, which means that you can omit error handling when indexing or slicing. The benefit of slices with unkown size is the ability to define functions with a variable sized argument `i64 parse_i64(slice_i8 *text)`. All slices have a len property which is the size of the slice. The cb compiler will keep track of which slices are compile time known in size and which are not.
# Coersion
cb will coerce some datatypes and datastructures automatically. A `byte` can always be coerced to an `int`. An `array` can always be coerced to a `slice`. For example, passing an array to a function that takes a slice as an argument is fine, since cb automatically coerces the array to a slice.
# Mutability
Everything is immutable by default. Make something mutable with the `mut` keyword: `mut int x = 5`
# Command line arguments
Access command line arguments in cb you use the builtin constant `args`.
# Loops
cb has one loop keyword. This loops forever:
```
loop
  ...
```
These are for loops:
```
loop list as num
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
# Indexing
Index a slice, list or array with the syntax `array[1]`. Please note that cb is one indexed. Cry about it. Arrays which are statically sized are bounds checked at compile time and don't need any error handling. However, slices or lists with unknown size require error handling. (Unless you're writing index 0 in which it's still a compiler error: `Error: cb is one-indexed.`). If you're not meaning to do proper error handling, then just use the `try` keyword like so `try slice[1]`. If you want proper error handling of out of bounds and such you'd use the `catch` or `switch` keyword as explained in their appropriet headers above.
### Why one-indexed?
Are you seriously going to tell me that getting the 5th element by writing `array[4]` is intuitive? Or that getting the first 5 elements by typing `array[0..5 ]` is intuitive? Do you seriously, with a straight face, say that zero-indexing is the most intuitive for beginners. Zero-indexing has forced every programming course to warn newcommers that programming is zero indexed beacuse the beginner would rightfully assume it to be one-indexed like any sane language designed for humans. Give me one good reason for zero-indexing that is not because it is the convention. The only reason we still use it is because we're too lazy to change it.
# Explicit error handling
You always need to handle errors. No matter what the operation is. Indexing can return an error after a bounds check. An arithmetic expression can be undefined (not as in the `undefined` keyword but as in division by zero for example). An arithmetic operation can overflow etc... cb forces you to always handle these errors no matter what. To skip writing proper error handling, write `try` before the operation: `try a - b * 9` and declare your function as an error union `!void function()`. The only expection to the rule are compile time known expressions, this means that you do not have to implement error handling on indexing or slicing arrays, since the bounds check can be performed at compile time. If any such expression is invalid by for example division by zero or indexing out of bounds cb will throw a compiler error.
# Runtime Errors
Because of cb's (possibly excessive) error handling is that runtime errors are all the more rare. That is, if you actually implement proper error handling, if you use the `try` keyword everywhere and never handle the errors, cb will of course still have runtime errors. cb programs can be analyzed statically for the possibility of runtime errors. As long as you do not put the `try` keyword in the top level of your program, your cb program will not have runtime errors.
# Scope
Scope in cb is a bit wierd. There are only two scopes: Function scope and Gobal scope. This might take some getting used to for seasoned developers. Beginners will have an easier time though. The reason for this is to make the borrow checker simple. This means that:
```
if true
  x = 2
print(x)
```
Will compile without any errors and print `2`.
# Pointers
Pointers are made with an asterix `*variable`. Dereference the pointer by removing the asterix `variable`. This is weird syntax compared to other languages however it less ambiguous. You can always be sure that an asterix before an identifier means it's a pointer and that nothing else can be a pointer. This also means that you cannot store a pointer in another variable. There is no pointer datatype. The only way to use a pointer is as a function argument. This is especially important to make the borrow checker simple.

The value pointers point to is immutable by default. Add the `mut` keyword to make the value behind the pointer mutable (`mut *variable`). This does not make the pointer mutable, only the value behind the pointer.
# Memory management
cb handles memory management through a borrow checker [similar to rust](https://rustc-dev-guide.rust-lang.org/borrow_check.html). But before you get scared and run away, please note that cb's borrow checkear is simplier than rusts. cb's borrow checker does not have lifetimes and it only enforces a simple set of rules:
- You cannot use a moved variable
- You cannot have an immutable pointer while having a mutable pointer to a value
- You cannot have a mutable pointer to an immutable value
- ...
# Comments
Comments start with a capital letter and end with one of: `.` `:` `!` `?` and a newline.
# Boolean expressions
Check for equality with `x = y`. Using chained comparisons is allowed `1 < x < 10`. Ambiguous boolean expressions are not allowed. `x and y or z` could be `(x and y) or z` or `x and (y or z)`.
# TODO
- [ ] Understand Webassembly
- [ ] Understand Webgl
- [ ] Redesign cb to be a sensible abstraction on top of webgl and Webassembly
- [ ] Finalise borrow checker rules
- [ ] Formal grammar specification
