# crust
Inspired by [Scratch](https://scratch.mit.edu/), [Lua](https://www.lua.org/start.html), [LÖVE](https://www.love2d.org/), [Rust](https://www.rust-lang.org/) and [Zig](https://ziglang.org/). A great first language and a great next language to learn after Scratch. Head over to the [website](https://b1nus.github.io/crust/) to start coding! Have fun!
# Simplicity Idea Nuggets
- All functions implicitly returns and reassigns their arguments.

Note: I need to do more market research. I don't understand my target audience at all.

Use simple words! Always. List is better than DynamicArrayList. etc.

At first glance, you don't seem to have enough features. but you do, you need to be creative. Just like in scratch.
# DEVNOTES: Website:
- Hotreloading. Just restart it for now, but make it only restart if necessary otherwise.
- Interactive helper. Haven't though to much of the details, but it's more or less a necessity.
- Auto indent. Tab and Tab remove easily.
# Mvp
- only wasm core
- only wasi preview 1
- only f64
# Developer notes
- Remember K.I.S.S:
- No expression statements
- No functions inside functions
- No capital letters
- No implicit return
- No add/sud/mul/div assign
- No swap optimisation
- No indexing syntax
- No default arguments
- No structs/enums
- No implicit types in bindings
- No error/crash messages
- No stacktraces
- No function overloading
- No methods
- No comptime
- No metaprogramming
- No bindings without initial expression
- No root indentation
- No function overriding
- [How hashmaps work](https://stackoverflow.com/a/15479974)
# Error handling
Just assertions. Avoid crashing with if statements.
> [!NOTE]
> Crashes show the assert that failed. We rely on good naming to make it obvious why it failed.
# Shadowing
Redeclare a variable to shadow it.
# Pointers
CHOPPING BLOCK -> Nope.
# Mutability
Everything is mutable.
# Memory
Memory is deallocated once a variable goes out of scope.
# Functions
All parameters are mutable. Functions are strongly typed.

CHOPPING BLOCK -> Functions cannot use variables from the outside, only their parameters.
# Numbers
- We have 5 kinds of number literals. Floats `1.5`, Decimal `58`, Hexadecimal `0x4B`, Binary `0b01001011`, and Character `"a"`.
- Compiler error if the literal is too big or too small.
- Chars can be any [utf-8](https://en.wikipedia.org/wiki/UTF-8) code point.
- f32 and f64 follow the normal rules of [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754).
# Strings
Strings are lists of numbers. `"Hello, World!"` is of type `[u8]` and each character is an element in the list. This is wasteful but very simple.
# Comments
Comments start with `//`.
# Boolean Expresssions
Chained boolean expressions `0 < x <= 10` are allowed. Ambiguous expressions such as `x and y or z` are not allowed.
# `use`
The `use` keyword imports code from local files, `use stuff/functions.crs`. You can give imported functions a namespace with the `as` keyword: `use stuff/function.crs as funcs`. Use a function from the imported file using dot syntax `x = funcs.function(args)`.
> [!NOTE]
> Don't forget to add the right line numbers and file names in error messages.
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
> [!NOTE]
> Consider adding integer types.
```
number random_number(number min, number max) // Crashes if NAN
bool is_whole_number(number x) // Crashes if NAN or INFINITY
bool is_infinity(number x)
bool is_nan(number x)
number infinity()
number nan()
number pi()
number e()
number absolute(number x) // Crashes if NAN
number round(number x) // Crashes if NAN or INFINITY
number floor(number x) // Crashes if NAN or INFINITY
number ceiling(number x) // Crashes if NAN or INFINITY
number sqrt(number x) // Crashes if NAN, INFINITY or negative
number sin(number x) // Crashes if NAN or INFINITY
number cos(number x) // Crashes if NAN or INFINITY
number tan(number x) // Crashes if cos(x) == 0 or x is NAN or INFINITY
number arcsin(number x) // Crashes if NAN or INFINITY
number arccos(number x) // Crashes if abs(x) > 1 NAN or INFINITY
number arctan(number x) // Crashes if NAN or INFINITY
number logarithm(number x) // Crashes if NAN or INFINITY or x <= 0
number bitwise_xor(number x, number y) // Crashes if NAN or INFINITY or not a whole number or too big
number bitwise_and(number x, number y) // Crashes if NAN or INFINITY or not a whole number or too big
number bitwise_or(number x, number y) // Crashes if NAN or INFINITY or not a whole number or too big
number bitwise_not(number x, number y) // Crashes if NAN or INFINITY or not a whole number or too big
number bitwise_shift(number x, number shift) // Crashes if NAN or INFINITY or shift not a whole number

+,-,/,*,%,^
>,>=,<=,<
and, or, not
```
# Lists
```
[number] list1 = [1, 3, -3, 7]
[number] list2 = "Hello, World!"

add_to_list([any] list, any item)
any pull_from_list([any] list) // Crashes if the list is empty
set_list_item([any] list, number index, any item) // Crashes if the index does not exist
remove_from_list([any] list, number index) // Crashes if the index does not exist
clear_list([any] list)
insert_into_list([any] list, any item, i64 index) 
number index([any] list, any item) // Crashes if the item does not exist
number list_length([any] list)
bool is_in_list([any] list, any item)
[any] join_lists([any] self, [any] other)
[any] repeat_list[any] list, number times)
[[any]] split_list([any] list, [any] separator)
```
# Maps
```
{[number]:number} map = {"you":10, "me":69}

set_map_value({any:any} map, any key, any value)
any get_map_value({any:any} map, any key) // Crashes if the key does not exist
delete_map_key({any:any} map, any key) // Crashes if the key does not exist
clear_map({any:any} map)
[any] keys({any:any} map)
number map_size({any:any} map)
bool is_in_map({any:any} map, any key)
```
# Sets
```
{number} set = {2, 3, 5, 7, 11}

add_to_set({any} set, any item)
remove_from_set({any} set, any item) // Crashes if it is not in the set
bool is_in_set({any} set, any item)
clear_set({any} set)
[any] set_as_list({any} set)
```
# Bundles
> [!WARNING]
> - This syntax relies on coloring to be readable.
> - This adds complexity.
```
bundle PLAYER
  number x
  number y
  [number] name

PLAYER player = PLAYER
  x = 0
  y = 0
  name = "Hejsan"

print(player.name)
```
> [!NOTE]
> `enum` could be useful. Call them `choice` to be more beginner friendly.
# Graphics
```
draw_image([number] path, number x, number y, number scale, f64 rotation)
draw_triangle(TRIANGLE triangle, COLOR color, number a)

clear_canvas(COLOR color)
RESOLUTION get_resolution()
```
# Audio
```
play_sound([number] path)
number get_volume()
set_volume(number new_volume) // Crashes if volume is not in the range 0-100.
```
# Input
```
MOUSE_POSITION mouse_position()
bool mouse_pressed([number] mouse_button) // Crashes if the mouse button name is invalid
bool is_mouse_just_pressed([number] mouse_button) // Crashes if the mouse button name is invalid
bool is_mouse_just_released([number] mouse_button) // Crashes if the mouse button name is invalid
bool is_key_pressed([number] key) // Crashes if the key is invalid
bool is_key_just_pressed([number] key) // Crashes if the key is invalid
bool is_key_just_released([number] key) // Crashes if the key is invalid

number seconds_since_start()
number seconds_since_2000()
```
# Text
```
number parse_number([number] text, number)
[number] format_number(number x, number decimals) // Crashes if decimals is not a whole number bigger bigger than or equal to zero.
print([number] text)
[[number]] command_line_arguments()
[number] read_input()
```
# Files
```
bool file_exists([number] path) 
bool is_readable([number] path) // Crashes if path does not exist
bool is_writeable([number] path) // Crashes if path does not exist
[number] read_file([number] path) // Crashes if we don't have access or path does not exist
write_file([number] path, [number] content) // Crashes if we don't have access or path does not exist
```
# Misc
```
assert(bool condition)
clone(any variable)
debug(any value)
```
