# crust
“If I had asked people what they wanted they would have said a simpler rust.”
# Main goals of crust
- simplicity & friendliness
- explicit error handling
- memory safety
# Usage
```
$ crust program.crs       Compile
$ crust program.crs -r    Run
$ crust program.crs -t    Test
$ crust program.crs -d    Debug
```
# Installation
> [!TODO]
# Webassembly
crust compiles to webassembly and uses [WASI](#WASI) for important functionality. Run your program with `$ crust program.crs -r`. 
## WASI
The Webassembly System Interface ([WASI](https://wasi.dev/)) is a set of API's to perform certain tasks in webassembly outside of a browser context. For example [using files](https://github.com/WebAssembly/wasi-filesystem?tab=readme-ov-file#goals), [using sockets](https://github.com/WebAssembly/wasi-sockets) or [using webgpu](https://github.com/WebAssembly/wasi-webgpu?tab=readme-ov-file#introduction). WASI is still in its infancy and crust will introduce features once they are introduced to WASI. 
# Game Development
## Graphics programming
> [!NOTE]
> crust will soon have a module called `graphics` for using [webgpu](https://en.wikipedia.org/wiki/WebGPU). crust is waiting for the [webgpu WASI API](https://github.com/WebAssembly/wasi-webgpu?tab=readme-ov-file#introduction).
## Networking, input and audio
> [!TODO]
> Figure out the state of the modules `network`, `input` and `audio` in WASI.
# Types
```
i64
i32
i16
i8
f64
f32
bool
range
array
slice
```
You can always explicitly declare the type of a variable, but you don't need to. crust defaults to the `i64` and `f64` types if no epxlicit type is given, same goes for strings which default to `array_i8` and ranges which default to `range_i64` and `range_f64`. Arrays can be written as either a list of values `[1, 2, 3]` or a string `"Hello world!"` (which is just an array of `i8`). The `slice` type is the same as an array but with an unknown size at compile time. Create a dynamically sized slice with `slice_i32 dynamic_slice = list(i32)` (`i32` can be any type of your choosing). Indexing is done with either a range of integers or just an integer, `slice = array[1..5]` and `element = array[3]`. Please note that any size of integer is allowed for indexing.
> [!NOTE]
> crust will infer and coerce certain types and values. A smaller integer will implicitly coerce into a larger integer `i8 + i16 = i16`. Same goes for `f32` coercing into `f64` and arrays implicitly coercing into slices. Integers also implicitly coerce into floats to make expressions such as `1 + 1.5` valid. You don't need to write the length of an array in when initialising it `array_i32 nums = [1, -2, 5]` will be infered to be `array3_i32 nums = [1, -2, 5]`.
> [!NOTE]
> Ranges are inclusive.
# Struct and Enums
crust provides ways to define your own types using the keywords `enum` and `struct`. Here we define a `struct` called `file`:
```
struct file
  slice_byte content
  slice_byte path
  mut bool empty = true
```
The attributes can have default values as shown with `file.empty` which is equal to `true`. All attributes are immutable by default and the keyword `mut` is used to make an attribute mutable. crust will make sure all attributes are set when a struct is instantiated. Instantiate a struct with the syntax
```
myfile = file
  content = "Hello World!"
  path = "./hello_world.txt"
```
Enums are a list of variants and variables can only take on one of those variants.
```
enum io_error
  file_not_found
  not_permitted
  out_of_memory
```
Here we're using the enum `io_error` to define a few errors which can occur for some operation. When you come across a variable of the type `io_error` you can be sure it's one of the variants `file_not_found`, `not_permitted` or `out_of_memory`.
# Optionals and Errors
The operators `?` and `!` are ways to augment types. `?type` makes the type nullable, meaning that it can be of value `null`. `!type` means that it can be an error. To specify a certain error type, write it to the left of the bang `error!type`.
# Lsp
Remember what you dislike about zls.
# Compiler
The crust compiler is a simple [one-pass compiler](https://en.wikipedia.org/wiki/One-pass_compiler).
## Command line interface
Errors should
- Be friendly and easy to understand (`crust is one-indexed`)
- Have the necessary information (file, location, values, stack trace etc...)
- Be pretty printed using ANSI
- Show the part of code in question
# Debugging
> [!TODO]
# Parser
indentation parsing from python.
# Import
Import code by using the `load` keyword (For example `load graphics`). By default this code is imported at the top level (the preprocessor is literaly just pasting the source code of the imported file), use the `as` keyword to give the code a namespace `load graphics as webgpu`. Import code from a local file by giving the path to the file prepended with a `./` (For example `load ./localfile.crs`).
> [!NOTE]
> crust will only allow loading code from files in the current directory or any subdirectories. crust will never load files from a parent directory.
## Downloading code from the internet
You are free to download the code in any way of your chosing, but using [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) is a good idea.
# Comptime
Force any expression to be evaluated at compile time using `comptime`. This functionality is borrowed from [zig](https://zig.guide/language-basics/comptime).
# Switch
Switch statements are a way to separate a value into different cases which are handled separately. crust will make sure that all possible cases are covered. For example, switching on an `i8` might look like this
```
i8 c = 'H'
switch c
  'a'..'z' => print("lower case letter")
  'A'..'Z' => print("upper case letter")
  '0'..'9' => print("digit")
  _ => print("other: %c")
```
# Catching Errors
The syntax for catching errors is the following:
```
function(1234) catch error
  ...
```
And with a switch statement
```
function(1234) catch error switch error
  ...
```
The long winded `catch error switch error` can be simplified to just `switch error`
```
function(1234) switch error
  ...
```
> [!NOTE]
> The compiler checks that you have covered all possibilites in your switch statement.
# Try
`try` is syntax sugar for the code block:
```
... catch error
  return error
```
With the `try` keyword you are propagating the error to another function. This is a quick and dirty way to handle errors and in a production environment you should use `catch` and `switch` to handle errors properly.
# Explicit error handling
crust requires you to explicitly handle all possible runtime errors. This includes out of bounds, division by zero, integer overflow etc. Use the `try` keyword to avoid proper error handling for the time being. Using `comptime` can also be a way to avoid explicit error handling since any error in a an expression known at compile time becomes a compiler error instead.
# Runtime Errors
Because of crust's (possibly excessive) error handling, runtime errors can be completely avoided. As long as you do not use the `try` keyword in the top-level or your program crust cannot have any runtime errors.
# Tests
Use the keyword `test` and write the boolean statement you want to test. For example `test x + y > 1`. If said test fails crust will show you the values of the variables:
```
$ crust program.crs -t
crust is testing program.crs...
  5 | passed!
  9 | passed!
  13 | failed at program.crs:13
    x + y > 1 is false because 0 + 1 > 1 is false
  20 | passed!
```
crust runs tests sequentially and doesn't exit upon failure. crust will also run any tests imported using the `load` keyword.
> [!TIP]
> Try moving more complicated tests into their own file.
# Excessive error catching
The benefit of arrays with known sizes is that the bounds check is performed at compile time. This means that you can omit error handling when indexing or slicing arrays.
# Coersion
crust will coerce some datatypes and datastructures automatically. A `byte` can always be coerced to an `int`. An `array` can always be coerced to a `slice`. For example, passing an array to a function that takes a slice as an argument is fine, since crust automatically coerces the array to a slice. The thing to watch out for is that itnegers also coerce into floats by default. This means that you can do arithmetic with floats and integers without any conversion. But it also means a loss in precision for large integers, it could be something to watch out for. 
# Mutability
Everything is immutable by default. Make something mutable with the `mut` keyword: `mut int x = 5`
# Command line arguments
Access command line arguments in crust you use the builtin constant `args`.
# Loops
crust has one loop keyword. This loops forever:
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
# Methods
Methods in crust are just normal functions. For example `bool contains(range_i64 *self, i64 num)` would be called as a method:
```
interval = 1..5
if interval.is_in_range(4)
  ...
```
# Multiple Dispatch
Two functions can have the same name as long as the have different type declarations. This is why `f64 sqrt(f64 self)` and `i64 sqrt(i64 self)` can have the same name. Also note that these functions can be called as methods `4.sqrt()`.
# One-Indexed
crust is one indexed. I know many programmers will wonder why I made this decision. Let me answer you by asking another question. What do you think is more intuitive, getting the 5th element in an array by typing `array[4]` or `array[5]`? What do you think is more intuitive for somebody new to programming? I would say it's the latter.
# Scope
Scope in crust is a bit wierd. There are only two scopes: function scope and gobal scope. This might take some getting used to for seasoned developers. Beginners will have an easier time though. This means that the program
```
if true
  x = 2
print(x)
```
Will compile and print `2`.
# Pointers
Pointers are made with an asterix `*variable`. Dereference the pointer by removing the asterix `variable`. You can always be sure that an asterix before an identifier means it's a pointer and that nothing else can be a pointer. Also note that you cannot store a pointer in a variable and that there is no pointer datatype. The only way to use a pointer is as a function argument. This is very important for making the borrow checker simple.

Pointers are immutable by default. Add the `mut` keyword to make the value behind the pointer mutable (`*mut variable`). This does not make the pointer mutable, only the value behind the pointer.
# Memory Safety
crust handles memory with a borrow checker. In contrast to [rust's borrow checker](https://rustc-dev-guide.rust-lang.org/borrow_check.html), crust does not have lifetimes and it only enforces simple set of rules:
- You cannot use a moved value
- You cannot have an immutable pointer while having a mutable pointer
- You cannot have a mutable pointer to an immutable value
- ...
# Comments
Comments start with a capital letter and end with one of `.` `:` `!` `?` and a newline.
# Boolean expressions
Check for equality with `x = y`. Using chained comparisons is allowed `1 < x < 10`. Ambiguous boolean expressions are not allowed. `x and y or z` is ambiguous because it can be interpreted as both `(x and y) or z` and `x and (y or z)`.
# TODO
- [ ] Watlings
- [ ] Webgpu codelab
- [ ] Ziglings
- [ ] Figure out how to fix painful parts of working with webgpu
- [ ] Figure out how to design crust to work well with webassembly
- [ ] Figure out how to handle `=` in boolean assignments (Remove them? KISS?)
- [x] Figure out how to handle byte literals (Remove them? KISS?)
- [ ] Figure out the situation of networking, input and audio in WASI
- [ ] Figure out how to make your own runtime
- [ ] Figure out how to make debugging easier
- [ ] Figure out how to format friendly, helpfull errors
- [ ] Decide if you want scope or not (even webassembly has local variables lmao) (Maybe loops should have scope) (If statements don't need scope though, right?)
- [ ] Figure out how to warn for top-level `try`
- [ ] Multiple return and Multiple assign (This is also supported in webassembly already lmao)
- [ ] Figure out reading and writing files in wasi (for the compiler to be able to be written in crust itself)
- [ ] Decide if you want unsigned integers
- [ ] Decide if you want error unions as values outside of being a function return type (Errors become more friendly if they are left out)
- [ ] How would you structure your polynomial library in crust? Maybe there is room for improvement.
- [ ] Decide if you want @compileError in crust. I think it's a great idea which solves the u64 p64 i64 problem.
- [ ] Optional captures in if statements?
- [ ] Decide how to do array concatenation and repetition (at compile time of course) (this is also for string concatenation since string literals are just arrays)
- [ ] catch instead of orelse?
- [ ] Figure out sensible syntax for handling errors such as overflow.
- [ ] Finalise inferense and coercion rules
- [ ] Finalise borrow checker rules
- [ ] Figure out how to get into the head space of a beginner programmer.
- [ ] Get feedback about the friendliness of the language. (This is a priority for me as I remember how many hiccups I've had when learning other langauges)
- [ ] Decide if you want to associate crust more with scratch. I want crust to be as simple and understandable as scratch. I hope a can make a language which I would have loved as a child. I need more feedback from people in this demographic.
- [ ] Formal grammar specification
- [ ] Rewrite the compiler in crust
