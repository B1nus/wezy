# cb
“If I had asked people what they wanted they would have said a simpler rust.”
# Main goals of cb
- simplicity & friendliness
- explicit error handling
- memory safety
# Usage
```
$ cb program.cb       Compile
$ cb program.cb -r    Run
$ cb program.cb -t    Test
```
# Webassembly
cb compiles to webassembly and will use the [WASI api](https://wasi.dev/) for performing operations such as reading files, networking etc. WASI is not [currently implemented](#WASI) and as a temporary solution cb compiles to a web application which can be run in a browser. Use `$ cb program.cb -r` to start your program.
## WASI
The Webassembly System Interface ([WASI](https://wasi.dev/)) is a set of API's to perform certain tasks in webassembly outside of a browser context. For example [reading files](https://github.com/WebAssembly/wasi-filesystem?tab=readme-ov-file#goals), [using sockets](https://github.com/WebAssembly/wasi-sockets) or [using webgpu](https://github.com/WebAssembly/wasi-webgpu?tab=readme-ov-file#introduction). The benefit of WASI and Webassembly is cross-compatilibity at near native performance. WASI is still in its infancy but in the near future cb won't have to rely on a browser.
# Game Development
## Graphics programming
cb has a module called `graphics` for interfacing with [webgpu](https://en.wikipedia.org/wiki/WebGPU). Include it using `load graphics`.
## Networking, input and audio
cb has the modules `network`, `input` and `audio` which you can import using the `load` keyword. cb is currently using javascript for this functionality.
> [!NOTE]
> cb was intended to use WASI instead of relying on javascript and browsers. When the WASI api is mature enough cb will compile to a single webassembly file which can be executed with a runtime such as [wasmtime](https://wasmtime.dev/).
Hmm type declaration is only for functions...
# Types
```
int
float
byte
bool
array
slice
```
In cb you never write the type of a variable. However, cb is still statically typed. This is possible because each literal corresponds to exactly one type. The only time you need to explicitly write types is when declaring functions. The `int` and `float` datatypes correspond to their respecitve types in [webassembly](https://webassembly.github.io/spec/core/syntax/types.html) (`i64` and `f64`). A number without a decimal point is infered to be an integer `i = 69` and a number with a decimal point is infered to be a float `f = 3.141`. A `bool` is a datatype with two values, `true` and `false`. An array is a list of values with a known size. An array literal can either be a list of values `[1, 2, 3]` or a string `"Hello world!"` which is just an array of bytes. The `slice` type is the same as an array, but it has an unknown size at compile time and needs error handling for out of bounds. Create a dynamically sized list with `list = slice`
# Struct and Enums
cb provides the keywords `enum` and `struct` to empower its typesystem. Think of them as a way to define your own types. A struct is a collection of attributes with a name. For example:
```
struct file
  slice_byte content
  slice_byte path
  mut bool   empty = true
```
The attributes can have a default value as shown with the attribute `empty`. All attributes are immutable by default and the keyword `mut` is used to make an attribute mutable. cb will make sure all attributes are set when a struct is instantiated at compile time, otherwise it will throw an error. Instantiate a struct with the syntax
```
myfile = file
  content = "Hello World!"
  path = "./hello_world.txt"
```
Enums, also called sumtypes is a way to define a variable which can be one of a set of variants. For example:
```
enum io_error
  file_not_found
  not_permitted
  out_of_memory
```
Using enums for errors is something you'll come across a lot in cb. Here we define an enum called `io_error` which has three variants. Each of which correspond to one type of error that can occur. When you declare a variable to be the `io_error` type you can be sure that is one of `file_not_found`, `not_permitted` or `out_of_memory` and nothing else. You can use this `io_error` as an argument to a function, as a return type or as an error a function can return with the bang `!` operator.
# Lsp
Remember what you dislike about zls.
# Compiler
The cb compiler is a simple [one-pass compiler](https://en.wikipedia.org/wiki/One-pass_compiler).
## Command line interface
Errors should
- Be friendly and easy to understand
- Have the necessary informations (file, location, values, stack trace etc...)
- Be pretty printed using ANSI
- Show the part of code in question
# Parser
indentation parsing from python.
# Import/Include
Import code or a module by using the `load` keyword (`load graphics`). By default this code is imported at the top level, use the `as` keyword to give the code a namespace `load graphics as webgpu`. The lack of quotation marks means that you're loading an module built into cb. To load a local file you put the relative path to the file inside quotation marks `load "localfile.cb"`. cb will only allow importing files in the current directory or subdirectories. cb will never load files in a parent directory. This is to make code easier to understand.
## Downloading code from the internet
You are free to download the code in any way of your chosing, but using [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) is a good idea.
# Comptime
Force any expression to be evaluated at compile time using `comptime`. This functionality is borrowed from [zig](https://zig.guide/language-basics/comptime).
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
  .type2 => Do something.
  .type3 =>
    Do something on
    multiple lines.
  .type4 => Do something.
  _ => Default case.
```
Which can be simplified with some syntax sugar:
```
x = function(1234) switch error
  .type1 => Do something.
  _ => Default case.
```
You're going to be switching on errors a lot in cb so this syntax sugar will be useful.
> [!NOTE]
> The compiler checks that you have covered all possibilites in your switch statement.
# Explicit error handling
cb requires you to explicitly handle all possible runtime errors. This include out of bounds, division by zero, integer overflow etc. Use the `try` keyword to avoid proper error handling for the time being. Using `comptime` can also be a way to avoid explicit error handling since any error in a an expression known at compile time becomes a compiler error instead.
# Tests
Use the keyword `test` and write the boolean statement you want to test. For example `test x + y > 1`. If said test fails cb will show you the values of the variables:
```
$ cb program.cb -t
cb is testing program.cb...
  5 | passed!
  9 | passed!
  13 | failed at program.cb:13
    x + y > 1 is false because 0 + 1 > 1 is false
  20 | passed!
```
cb runs tests sequentially and doesn't exit upon failure. cb will also run any tests imported using the `load` keyword.
> [!TIP]
> Try moving more complicated tests into their own file.
# Excessive error catching
The benefit of arrays with known sizes is that the bounds check is performed at compile time. This means that you can omit error handling when indexing or slicing arrays.
# Coersion
cb will coerce some datatypes and datastructures automatically. A `byte` can always be coerced to an `int`. An `array` can always be coerced to a `slice`. For example, passing an array to a function that takes a slice as an argument is fine, since cb automatically coerces the array to a slice. The thing to watch out for is that itnegers also coerce into floats by default. This means that you can do arithmetic with floats and integers without any conversion. But it also means a loss in precision for large integers, it could be something to watch out for. 
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
# Runtime Errors
Because of cb's (possibly excessive) error handling runtime errors are all the more rare. As long as you do not put the `try` keyword in the top level of your program, your cb program will not have any runtime errors.
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
Comments start with a capital letter and end with one of `.` `:` `!` `?` and a newline.
# Boolean expressions
Check for equality with `x = y`. When assigning a boolean value you use `:` instead of `=` to avoid confusion: `p: x = 5` instead of `p = (x = 5)`. Using chained comparisons is allowed `1 < x < 10`. Ambiguous boolean expressions are not allowed. `x and y or z` is ambiguous because it can be interpreted as both `(x and y) or z` and `x and (y or z)`.
# TODO
- [ ] Watlings
- [ ] Webgpu codelab
- [ ] Figure out how to fix painful parts of working with webgpu
- [ ] Figure out how to design cb to work well with webassembly
- [ ] Figure out how to handle `=` in boolean assignments
- [ ] Finalise borrow checker rules
- [ ] Formal grammar specification
