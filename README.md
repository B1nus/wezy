# Placeholder Name
Inspired by [Scratch](https://scratch.mit.edu/), [Lua](https://www.lua.org/start.html), [LÖVE](https://www.love2d.org/) and [Zig](https://ziglang.org/). A great first language, and a great next language to learn after Scratch. It will introduce some lower level concepts such as floats and bitwise operations and introduce you to a development environment similar to most other languages.

Funily enough, the language is quite low level. Even though it might not feel like it. It's similar to the amount of abstraction of C. Unlike llvm I won't add any crazy optimisations, I want to keep the compiler simple and predictable. One of my goals is that a user should never be suprised when using this language.

I don't want users to be confused about what will happen when they run their code. This is why you can't pass list/map reference to a new variable. You are forced to use the `clone()` function and create a new list. . This is something I plan to keep consistent in my language.
# Goals
- simplicity & friendliness
- no magic
# Mvp
- only compile to website
- only webgl
- only wasm core
- only f32
- only i32
# Borrow Checker
- Moving is never allowed
- A value can not be used after it goes out of scope
> [!NOTE]
> Figure out the exactly what the borrow checker needs to check. The list should not be very long.
>
> The borrow checkers goal is not memory safety, just to free stuff that's not used. If a user has a reference to a list item and then removes that list item, the program simply crashes if it tries to use it. This language is not supposed to be used in security critical sutiations, so that convenience is well worth it.
# Functions
> [!NOTE]
> Figure out the function syntax. It should align with the design goals of being simple, easy for beginners and consise.
- Functions are strongly typed, meaning that you have to declare the input and output types.
- They can return multiple values. Which you then have to use a multiple assign on.
- all arguments are mutable. (They are just pointers under the hood, immutability does not exist in this language)
- cannot use variables from outside, only their arguments.
# Types
- We have 3 kinds of literals for numbers. Floats `1.0`, Integers `58` and Bytes `'a'`. The Bytes value is the characters value in [ascii](https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fupload.wikimedia.org%2Fwikipedia%2Fcommons%2Fthumb%2Fd%2Fdd%2FASCII-Table.svg%2F2522px-ASCII-Table.svg.png&f=1&nofb=1&ipt=d06751b1640d9b550ceeb692df4b97fa295a63c012adbe3822e5ec24809bd801&ipo=images) and has the type `i8`.
- Integer literals can be in binary `0b01001011`, hexadecimal `0x4B` and decimal `75`.
- Integers can be of any size that's an exponent of 2. In other words `i8, i16, i32, i64, i128, i256, i512 ...`. They can be as big as you want.
- floats have one size `f64` which is a 64-bit floating point number following the normal rules of [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754).
- Expansion of integers is implicit. (`i32 x = 'b'`)
- Conversion to `f64` is implicit. (`f64 x = 5`)
- Divison always returns an `f64`. Use `ceil()`, `floor()` or `round()` to make it into an integer.
- `f64` is choosen before an integer, a larger integer is choosen before the smaller integers. `5 + 5.0` is a `f64` and `5 + 'a'` is an `i64`.
- No conversion functions. use type declarations `i8 x = 4`. To clarify: `x = 4` would give you an `ì64`
> [!NOTE]
> Please try to simplify these rules, they are unwieldy.
# Comments
Comments start with `//` and keep going until the ond of the line.
# Boolean Expresssions
Chained `0 < x <= 10`. Ambiguous expressions such as `x and y or z` are not allowed.
# `use`
The `use` keyword imports code into your file. It can import local files `use stuff/functions.crs`. By default the contents are put in the top level of your file, name collisions are possible. You can give them a namespace with the `as` keyword: `use stuff/function.crs as funcs`.

`Use` can be used to gain access to a lower level of the language. There is a builtin module called `webgpu` which is secretly what the `draw` function is using under the hood. There is a reason this is hidden however, the complexity insane. Most (including myself) are better of just using the `draw` function. There is also the `memory` module for access to `alloc`, `realloc` and `free`.
> [!NOTE]
> Think this through a bit more. Maybe this is not needed. Maybe we don't need to add another concept to the language.
# Control
```
if condition
  statements
else
  statements

loop 42
  statements

loop
  if condition
    break
```
# Math
```
+,-,/,*
random(min, max)
>,>=,<=,<
and, or, not
mod(x, y)
round(x)
floor(x)
ceil(x)
abs(x)
sqrt(x)
sin(x)
cos(x)
tan(x)
arcsin(x)
arccos(x)
arctan(x)
ln(x)
exp(x)

// Maybe not. (These are bitwise operations)
xor(x,y)
and(x,y)
or(x,y)
not(x)
```
# Lists
```
numbers = [1, 3, -3, 7]
hello_world = "Hello, World!"
split = hello_world.split(' ')

push(item)
pull()
remove(index)
clear()
insert(item, index)
replace(old, new)
index(item)
length()
contains(item)
join(other)
clone()
repeat(times)
split(separator)
```
# Maps
```
ages = {"you":10, "me":69}

set(key, value)
delete(key)
clear()
value(key)
keys()
size()
has(key)
clone()
```
# Graphics
```
draw_image(path, x, y, rotation)
draw_triangle(x1, y1, x2, y2, x3, y3, r, g, b, a)
draw_triangle_image(path, x1. y1, x2, y2, x3, y3, uv_x1, uv_y1, uv_x2, uv_y2, uv_x3, uv_y3)

clear_canvas(r, g, b, a)
resolution()
```
# Audio
```
play(path)
volume()
set_volume(vol)
```
# Input
```
mouse_position()
mouse_pressed()
key_pressed(key)
```
# Files
```
read(path)
write(path, contents)
parse_i64(text)
parse_f64(text)
format(value)
print(text)
input()
args()
```
# Debugging
```
show(any)
hide(any)
time()
```
# Networking
TODO!
> [!WARNING]
> The user has to memorize if a function is standalone or a method. Either make the pattern obvious or make everything into either methods of normal functions.
# Remember
- Lists, and Maps are not allowed in arithmetic expressions. You cannot repeat a string like this `"hello"`. You can only use the repeat function. Why? Simplicity of course, now you won't have to ask yourself. Hmmm, is that a number or a list? And users won't have to learn two ways of doing things, only one. This is a general mantra of this language, keep things simple with only one way to do a thing.
- Don't add both attributes and methods, just make everything into methods. A way to decrease the number of abstraction a user has to learn. In other words, a way to make the language simpler.
- Rotation is in degrees. that holds for sin, cos, tan, asin, acos, atan etc... (should I name asin as arcsin to avoid confusion for newcommers? I remeber being confused by that when I was little)
- Every literal should have an assumed type, so that you don't force users to write the type explicitly, or well, maybe you should make them do that i dunno. It's probably annoying for newcommers.
- One indexing. And if you add ranges, make them inclusive, I have no idea why othera languages don't make them inclusive, it makes life so much easier.

# Compiler design
- The builtin functions should be easy tu understand from source code. (no magic, the language is implemented in itself, no catch)
- Easy to switch from browser to wasi as host
- Load the files for the users and reuse.
- Import functions for the users, only the functions they actually use.
- Fast and tiny binaries. As simple as possible.

# Implementation details
- bigger ints are just many `i64` in function arguments
- mutable arguments are not a thing in wasm, so return the parameters and update the value after calling the function. wasm thankfully supports multiple return out of the box.
- Everything is utf-8 encoded.
- Webgl for rendering.
- No function name mangling. "_start" cannot be a name in crust because it starts with an underscore

# MVP
- compiles applications that use audio, graphics or input as a website.
- webgl for rendering with a javascript shim.
> [!NOTE]
> Should we compile everything to a single *index.html* file? Or should we split it up and embrase html, wasm, js and css and take advantage of them for making the website? It' smarter to use css, and html to style a website, but a beginner will have a very hard time with learning 4 languages at once. I'm torn. We either hide the complexity and lose convenience, or we embrace the complexity and make websites like real webdevs.

> [!NOTE]
> Teach people in a good way how to serve the website. I remember how confusing this was for me when I started out.

> [!NOTE]
> Maybe you can use the component system to make the transition between hosts smoother? (import the same functions names, but export them from either js or wasi)

# Website
- written in the language itself
- lsp, treesitter and documentation built in. A user should not be missing anything.
- easy way to post and interact with eachother.

# Scratch Features I want to integrate somehow
- Easy way to see all functions. (lsp?)
- Hot reloading
- Click to see value
- Click to run function
- Show/Hide variable

# Features I'm not going to add
- loops/if as values
- errors as values
- swizzling
- iterators
- nullable
- switch
- function overloading
- methods
- structs
- enums
- slices
- generics
- attributes
- strings, we already have lists.
- big_int

crust's philosophy is that optimisation is the programmers responisiblity, not the compilers. The compiler is a tool. A predictable program which does what you expect it to. I want programmers to be able to predict what crust code will look like in webassembly and use this understanding to their advantage. I don't want the compiler to be a black box full of magic.

Be carefull about what abstractions you include. Try to keep them to a minimum for the sake of simplicity. When in doubt, take a look at what Scratch and Lua are doing. Usually, they do it in the most simple way possible. Only having list and not arrays and slices was good for example, that is inspired by scratch. We should also try to avoid concepts such as interfaces or comptime, which is way too complicated for my goals.
# MVP (Minimum Viable Product)
- read()
- write()
- i8, i16, i32, i64, i128 etc..
- borrowchecker
- try/catch/switch
- enums and the bang `!` operator
- functions
- return
- assignment
- expressions
- only ascii (if c < 0 error)
# Web editor
crust has an official web editor where you can write and run crust code. You can find it [here](https://pages.github.com/).
# Command Line Usage
crust has a command line utility for compiling and running crust code. Here are the commands provided by crust:
```
$ crust program.crs       Run
$ crust program.crs -c    Compile to WebAssembly/WebApplication
$ crust program.crs -t    Test
$ crust program.crs -d    Debug
```
> [!NOTE]
> crust is compiled to webassembly, the specifics of running webassembly is shown [below](#Installation)
# Installation
Install [crust.wasm](github.com/B1nus/crust/releases) and run it with your [favourite WebAssembly runtime](https://github.com/appcypher/awesome-wasm-runtimes). Here is an example of how to do that with [wasmtime](https://wasmtime.dev/): `$ wasmtime --dir=. crust.wasm`. This command runs the crust command line utility with access to the current directory. The: `--dir=.` is needed because WebAssembly is sandboxed by default and needs explicit permission to use the filesystem. Passing arguments to crust is as easy as writing them at the end: `$ wasmtime --dir=. crust.wasm program.crs -d`, this runs `program.crs` in debug mode.
# Hello World
```
print("Hello, World!")
```
Save this to a file and run it using the [*crust.wasm*](github.com/B1nus/crust/releases) file and a wasm runtime.
# Game Development
## Graphics programming
> [!NOTE]
> crust will soon have a module called `graphics` for drawing to the screen. For lower level control of the graphics you can use the module `gpu` which gives you full control over the [webgpu graphics backend](https://en.m.wikipedia.org/wiki/WebGPU). Please keep in mind that it's very overwhelming to use webgpu directly. Most users (including myself) will be better of using the `graphics` module for their projects.

> [!WARNING]
> These modules are currently unavailable since webgpu isn't supported by [WASI](https://wasi.dev/).
## Networking, input and audio
The modules `input` and `network` have functions for taking input and networking respectively.
> [!TODO]
> Figure out the state of `audio` in wasi.
# Types
```
i64
f64
bool
range
list
map
```
- Arbitrary sized integers `i29`, `i512`.
- Hexadecimal `0x0045`, Binary `0b1000101` and decimal `69` integer literals.
- byte literals `'a'`.
- One-indexed and inclusive `1..5` are the numbers `1`, `2`, `3`, `4`, and `5`.
- crust can always infer a type. For example: `5` is a `i64`, `0..0.5` is a `range_f64` and `"hello world!"` is a `list_i8`. This is true `['h','e','l','l','o'] = "hello"`.
- ranged indexing returns anothes list. Removing items from this removes items from the original list. Use copy to get a copy of the list.
- iterators are just structs with the next method. nothing fancy.
# User Defined types
```
struct
enum
```
crust provides ways to define your own types using the keywords `enum` and `struct`. Here we define a `struct` called `file`:
```
struct file
  list_i8 content
  list_i8 path
  mut empty = true
```
The attributes can have default values as shown with `file.empty` which is equal to `true`, this also let's us avoid writing the type as `bool`. All attributes are immutable by default and the keyword `mut` is used to make an attribute mutable. crust will make sure all attributes are set when a struct is instantiated. Instantiate a struct with the syntax
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
Here we're using the enum to define `io_error` which is a list of errors which can occur when using files. When you come across a variable of type `io_error` you can be sure it's one of the variants `file_not_found`, `not_permitted` or `out_of_memory`.
# Optionals and Errors
The operators `?` and `!` are ways to augment types. `?type` makes the type nullable, meaning that it can be of value `null`. `!type` means that it can be an error. To specify a certain error type, write it to the left of the bang `error!type`.
# Compiler
The crust compiler is a simple [one-pass compiler](https://en.wikipedia.org/wiki/One-pass_compiler).
## Command line interface
Errors should
- Be friendly and easy to understand (`crust is one-indexed`) (`crust can't find the file, did you give it permission?`)
- Have the necessary information (file, location, values, stack trace etc...)
- Be pretty printed using ANSI
- Show the part of code in question
# Parser
indentation parsing from python.
# Import
Import code by using the `copy` keyword (For example `copy graphics`). By default this code is imported at the top level of your file. Use the `as` keyword to give the imported code a namespace `copy graphics as gfx`. Import code from a local file by giving the path to the file prepended with a `./` (For example `copy ./local_file.crs`).
> [!NOTE]
> crust will only allow loading code from files in the current directory or any subdirectories. crust will never load files from a parent directory. crust can never access files outside of the sandboxed environment as enforced by your WebAssembly runtime.
## Downloading code from the internet
You are free to download the code in any way of your chosing, but using [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) is a good idea.

**Why no package manager?**
crust hopes to include everything needed in tha language itself. The hope is that a user rarely needs to reach for a third party library.
# Switch
Switch statements are a way to separate a value into different cases which are handled separately. crust will make sure that all possible cases are covered. For example, switching on an `i8` might look like this
```
i8 c = 'H'
switch c
  'a'..'z' => print("lower case letter")
  'A'..'Z' => print("upper case letter")
  '0'..'9' => print("digit")
  _ => print("other: " + format(c))
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
crust requires you to explicitly handle all possible runtime errors. This includes out of bounds, division by zero, integer overflow etc. Use the `try` keyword to avoid proper error handling for the time being. Compiletime known expressions don't need error handling, since the errors will be shown while compiling.
# Runtime Errors
Because of crust's (possibly excessive) error handling, runtime errors can be completely avoided. As long as you do not use the `try` keyword in the top-level or your program crust cannot have any runtime errors. Well, except for out of memory errors, they still crash your program.
# Tests
Use the keyword `assert` and write the boolean statement you want to test. For example `assert x + y > 1`. Write more complicated tests inside of a `test` block:
```
test Addition.
  x = 0
  y = 1
  assert x + y > 1
```
If said test fails, crust will show you the values of the variables:
```
$ crust program.crs -t
crust is testing program.crs...
  5 | passed!
  9 | passed!
  13 | "Addition." failed at program.crs:13
    x + y > 1 is false because 0 + 1 > 1 is false
  20 | passed!
```
crust runs tests sequentially and doesn't exit upon failure. crust will also run any tests imported using the `load` keyword. 
# Excessive error catching
The benefit of arrays with known sizes is that the bounds check is performed at compile time. This means that you can omit error handling when indexing or slicing arrays.
# Coersion
crust will coerce some datatypes and datastructures automatically. A `i8` can always be coerced to an `i64`. The thing to watch out for is that integers also coerce into `f64`. This means that you can do arithmetic with floats and integers without any conversion. But it also means a loss in precision for large integers. There is also a performance penalty.
# Mutability
Everything is immutable by default. Make something mutable with the `mut` keyword `mut x = 5`
# Command line arguments
Access command line arguments with the builtin constant `args`
# Loops
crust has one loop keyword. This loops forever:
```
loop
  ...
```
This loops over all numbers from 1 to 10
```
loop 1..10 as i
  ...
```
This loops over all items in a list
```
loop list as num
  ...
```
This is a while loop
```
loop
  break if ...
```
## Lables
Loops can have labels in order to differentiate in nested loops:
```
outer: loop
  inner: loop
    break :outer if ...
...
```
This syntax will probably change.
# Methods
Methods in crust are normal functions. For example `bool contains(range_i64 *self, i64 num)` could be called as a method:
```
interval = 1..5
if interval.contains(4)
  ...
```
# Multiple Dispatch
Two functions can have the same name as long as the have different type declarations. This is why `f64 sqrt(f64 self)` and `i64 sqrt(i64 self)` can have the same name. Also note that these functions can be called as methods `4.sqrt()`.
# Builtin functions
Builtin functions such as `parse` and `format` do not play by the normal rules of crust. This is because they are [generic](https://en.wikipedia.org/wiki/Generic_function).
# One-Indexed
crust is one indexed. I know many programmers will wonder why I made this decision. Let me answer you by asking another question. What do you think is more intuitive, getting the 5th element in an array by typing `list[4]` or `list[5]`? What do you think is more intuitive for somebody new to programming? I would say it's the latter.
# Pointers
Pointers are made with an asterix `*variable`. Dereference the pointer by removing the asterix `variable`. You can always be sure that an asterix before an identifier means it's a pointer. Also note that you cannot store a pointer in a variable and that there is no pointer datatype. The only way to use a pointer is as a function argument. This is very important for making the borrow checker simple.

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
Check for equality with `x = y`. Using chained comparisons is allowed `1 < x < 10`. Ambiguous boolean expressions are not allowed. `x and y or z` is ambiguous because it can be interpreted as `(x and y) or z` or `x and (y or z)`.
# Bitwise manipulations
**Hmmm...** operators or builtin functions.
# Overflow error
You do not need to handle all overflow errors, but crust makes it really easy to handle them when you need to. If an overflow occurs without error handling, it crashes.
# Out of memory
crust will crash, there is no way to handle these errors. In 99.99% of cases your program should crash if it is out of memory.
# No hidden control flows
The standard library should be implemented in the language itself, no magic.
# Credit
I want to give credit to all of the programming languages which I've looked at for guidence: [Lua](https://www.lua.org/start.html), [Zig](https://ziglang.org/), [C](https://en.wikipedia.org/wiki/C_(programming_language)), [Rust](https://www.rust-lang.org/), [Scratch](https://scratch.mit.edu/), [WASM](https://webassembly.org/). Thank you for all of the help, and sorry for stealing your features (Mostly zig's...). I also want to give credit to [Ziglings](https://codeberg.org/ziglings/exercises/src/branch/main) and [Watlings](https://github.com/EmNudge/watlings) which helped me learn zig and webassembly. I also want to give credit to this [codelab](https://codelabs.developers.google.com/your-first-webgpu-app) and [learn webgl](https://learnwebgl.brown37.net/) which is an amazing resourse. 
# TODO
- [x] Watlings
- [ ] Webgpu codelab
- [ ] Learn webgl
- [x] Writing an interpreter in go
- [ ] Crafting Interpreters
- [x] Ziglings
- [ ] aoc in zig
- [ ] Fix painful parts of working with webgpu (less unnecessary repetition of types)
- [ ] Simplified high level module for working with webgpu (the `graphics` module)
- [ ] Figure out how to design crust to work well with webassembly
- [ ] Figure out how to handle `=` in boolean assignments
- [x] Decide if unsigned integers are needed.
- [ ] Test output format
- [ ] Friendly errors
- [ ] Default argument values
- [ ] Decide if you want scope or not (even webassembly has local variables lmao) (Maybe loops should have scope) (If statements don't need scope though, right?)
- [ ] Figure out how to warn for top-level `try`
- [ ] Multiple return and Multiple assign (This is also supported in webassembly already lmao)
- [ ] Efficient swap algorithm with [xor](https://en.wikipedia.org/wiki/XOR_swap_algorithm).
- [ ] Figure out reading and writing files in wasi (for the compiler to be able to be written in crust itself)
- [x] Decide if you want unsigned integers
- [ ] How would you structure your polynomial library in crust? Maybe there is room for improvement.
- [ ] Decide if you want @compileError in crust. I think it's a great idea which solves the u64 p64 i64 problem.
- [ ] Optional captures in if statements?
- [ ] Decide how lists should work. (operations `+ *`) (creation `numbers = [1, 2, 3]`)
- [ ] Decide how to handle null as a normal error with just one type.
- [ ] Figure out sensible syntax for handling errors such as overflow.
- [ ] Decide if overflow/indexing error handling should be manditory. (Has big consequences for the language)
- [ ] Finalise inferense and coercion rules
- [ ] Finalise borrow checker rules
- [ ] Get feedback from beginners.
- [ ] Get feedback about the friendliness of the language. (This is a priority for me as I remember how many hiccups I've had when learning other langauges)
- [ ] Decide if you want to associate crust more with scratch. I want crust to be as simple and understandable as scratch. I hope a can make a language which I would have loved as a child. I need more feedback from people to achieve this.
- [ ] Formal grammar specification
- [ ] Keywords
- [ ] Write the compiler in crust
- [ ] Compile to website
- [ ] Write the web editor in crust
- [ ] Errors for float operations (infinity, nan etc)
- [ ] Decide if loops and if and switch statements should have values
- [ ] Decide how to handle switch statements return values (zig can be annoying with the type being returned)
- [ ] Switch statements can take in values
- [ ] Functions should not be able to take mutable variables from the outside. only immutable ones. (now they can be used as closures no problem) (also, it's just good to be able to see in the function declaration if it's mutating anything)
- [x] interfaces/traits? (Maybe it's too complicated)
- [x] remove comptime? (It's too complicated)
- [ ] Come up with a simpler version of comptime/traits if it is needed. (Decide after making the language).
- [x] labels (must have)
- [ ] Label syntax
- [x] hashmaps?
- [ ] map literals.
- [ ] MVP
- [ ] panic? todo? unreachable? (Purposfully removes certainty that your program can't crash) (Never use in std, the user should have full control of when to panic)
- [ ] Implicit conversion from any number to another in call expressions, or anywhere really. This is only for non-destructive I.E. i8 to i64, i32 to f64 etc...
- [ ] Remove multiple dispatch?
- [ ] Pointer assignment in struct fields?
- [ ] No more scope? (In the same way as go letting pointers to locally constructed variables live longer than their scope, This make so much sense to me, and it really does moake sense from a hardware standpoint, there is no reason this should be impossible)
- [ ] How exactly should list "slices" work. for example removing from a list slice.
- [x] integers of any size?
- [ ] Multiple assign/return syntax
- [ ] List slicing.
- [ ] Implicit type conversion with multiple dispatch
- [ ] Lsp (Remember what you dislike about zls)
- [ ] Debugger (Maybe not so important if we have good runtime errors)
- [ ] Errors can not be assigned to a variable.
- [ ] Sum types.
- [ ] Remove Structs?
- [ ] Remove Ranges?
- [ ] combine print and write into one? (multiple dispatch)
- [ ] combine format with write/print? (multiple dispatch)
- [ ] Labled switch with continue/break with values? [(Performant and cool)](https://github.com/ziglang/zig/pull/21367)
- [ ] [Data oriented programming](https://www.youtube.com/watch?v=rX0ItVEVjHc&t=0s) [Andre Kelley (creator of zig)](https://www.youtube.com/watch?v=IroPQ150F6c) [Handles are the better pointers](https://floooh.github.io/2018/06/17/handles-vs-pointers.html). Me likey.
- [ ] [Wit has a nice collection of types](https://component-model.bytecodealliance.org/design/wit.html#built-in-types). Try to understand wit a bit more.
- [ ] Easy way to publish crust projects. (here, wasm sanboxing is really important)

Functions cannot mutate variables from the outer scope. They can however use immutable variables from the outer scope. And they can of course mutate variables in the outer scope if given a pointer through a argument, however, they can never do it otherwise.

What is crust? Friendly, as easy and concise as python, but with strict rules on error handling and closely mimicing webassembly. crust aims to have few abstractions as possible while still being capable of expressing complex logic in a natural way.
