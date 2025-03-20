# crust
Inspired by [Scratch](https://scratch.mit.edu/), [Lua](https://www.lua.org/start.html), [LÖVE](https://www.love2d.org/), [Rust](https://www.rust-lang.org/) and [Zig](https://ziglang.org/). A great first language and a great next language to learn after Scratch. It will introduce low level concepts such as floating point numbers and bitwise operations.
# Goals
- simplicity
> [!NOTE]
> 1. It's hard to know if something is a function or method
>  - Only functions
>  - Function overloading
> 3. There are too many implicit number rules
>  - Have one integer type
>  - Have one integer type and one byte type
>  - Have a integer type which is a collective name for all integers
>  - Explicit number conversion
>  - All numbers are f64

Two choices:
1. u8, u16, u32, u27, i8 etc... and f64
2. only floats and bytes. <- much easier to implement start here

# Mvp
- only wasm core
- only wasi preview 1
- only integers
# Error handling
Just assertions. Avoid crashing with if statements.
# Pointers
Nope.
# Mutability
Everything is mutable.
# Memory
Memory is deallocated once a variable goes out of scope.
# Functions
All parameters are mutable references. Functions are strongly typed. Functions cannot use varibles from the outside, only their parameters. They can return mutliple values using tuples.
# Types
- We have 5 kinds of number literals. Floats `1.0`, Decimal `58`, Hexadecimal `0x4B`, Binary `0b01001011`, and Chars `'a'`.
- Chars can be any [utf-8](https://en.wikipedia.org/wiki/UTF-8) code point and has the samllest possible integer type out of `i8`, `i16` and `i32`.
- Integers can be any size that's an exponent of 2, `i8, i16, i32, i64, i128, i256, i512 ...`.
- floats have one size `f64` which is a 64-bit floating point number following the normal rules of [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754).
- Conversions are implicit. Use type declarations to convert between types. (`i64 x = 'a'`)
- The program crashes if the conversion is impossible. (`i8 = 923837`)
- Division always returns an `f64`. Use `div_i64()` for integer division.
- The type of an expression is the largest integer in the expression or `f64` if there is a float involved anywhere.
- Integer literals are assumed to be i64 unless given another type.
> [!NOTE]
> Hmmm... what is this trying to solve?
> Well in trivial cases such as 1 + 1.5 we don't want to be explicit about the type. And if for example using `function('a')` that conversion is implicit or when sending integers to a function taking only floats. Is there anything else? Idk. but it introduces a lot confusing sutiations when it's hard to know the static type of a variable. This is a hard call.
>
> So, it's about how we imply a type to expressions.
> It's about how we do conversion implicitly for number types in arguments to functions.
> That's it. You always have the choice to be explicit with type declarations.
# Comments
Comments start with `//`.
# Boolean Expresssions
Chained bollean expressions `0 < x <= 10` are allowed. Ambiguous expressions such as `x and y or z` are not allowed.
# `use`
The `use` keyword imports code from local files, `use stuff/functions.crs`. By default the contents are put in the top level of your file, name collisions are possible. You can give them a namespace with the `as` keyword: `use stuff/function.crs as funcs`.
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
> It might be better to add integer types.
```
number random_number(number min, number max) // Crashes if NAN
bool is_whole_number(number x) // Crashes if NAN or INFINITY
bool is_not_a_number(number x)
bool is_infinity(number x)
number modulus(number x) // Crashes if NAN or INFINITY
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
number exponential(number x) // Crashes if NAN or INFINITY
number bitwise_xor(number x, number y) // Crashes if NAN or INFINITY or not a whole number or too big
number bitwise_and(number x, number y) // Crashes if NAN or INFINITY or not a whole number or too big
number bitwise_or(number x, number y) // Crashes if NAN or INFINITY or not a whole number or too big
number bitwise_not(number x, number y) // Crashes if NAN or INFINITY or not a whole number or too big
number bitwise_shift(number x, number shift) // Crashes if NAN or INFINITY or shift not a whole number
+,-,/,*
>,>=,<=,<
and, or, not
```
# Lists
```
list1 = [1, 3, -3, 7]
list2 = "Hello, World!"

add_to_list([any] list, any item)
any pull_from_list([any] list) // Crashes if the list is empty
set_list_item([any] list, number index, any item) // Crashes if the index does not exist
remove_from_list([any] list, number index) // Crashes if the index does not exist
clear_list([any] list)
insert_to_list([any] list, any item, i64 index) 
number index([any] list, any item) // Crashes if the item does not exist
i64 length([any] list)
bool contains([any] list, any item)
[any] join([any] self, [any] other)
[any] clone([any] list)
[any] repeat[any] list, (i64 times)
[[any]] split([any] separator)
```
# Maps
```
{[i8]:i32} map = {"you":10, "me":69}

set(any key, any value)
get(any key) // Crashes if the key does not exist
delete(any key) // Crashes if the key does not exist=
clear()
[any] keys()
i64 size()
bool has(any key)
{any:any} clone()
```
# Tuples
```
(i32, [i8], i8, f64) tuple = (1, "Hello", '\n', 5.9)

get(i32 index) // Crashes if the index is not in range
set(i32 index) // Crashes if the index is not in range
i32 size()
```
# Graphics
```
draw_image([i8] path, f64 x, f64 y, f64 scale, f64 rotation)
draw_triangle(f64 x1, f64 y1, f64 x2, f64 y2, f64 x3, f64 y3, f64 r, f64 g, f64 b, f64 a)

clear_canvas(f64 r, f64 g, f64 b)
(i64, i64) get_resolution()
```
# Audio
```
play([i8] path)
f64 get_volume()
set_volume(f64 vol)
```
# Input
```
(i64, i64) mouse_position()
bool mouse_pressed()
bool key_pressed(i8 key)

i64 nanoseconds_since_start()
i64 seconds_since_2000()
```
# Text
```
bool exists(path) 
bool has_write_access(path) // Crashes if path does not exist
bool has_read_access(path) // Crashes if path does not exist
[i8] read(path) // Crashes if we don't have access
write([i8] path, [i8] content) // Crashes if we don't have access
i64 parse_i64([i8] text, i64 base) // Crashes if it's not a i64
f64 parse_f64([i8] text) // Crashes if it's not a f64
[i8] format_i64(i64 x, i64 base) // Crashes if the base is less than 2
[i8] format_f64(f64 x, i64 decimals) // Crashes if decimals is negative
print([i8] text)
[i8] input()
[[i8]] command_line_arguments()
```
# Debugging
```
assert(bool condition)
debug(any value)
```
