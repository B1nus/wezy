# crust
Inspired by [Scratch](https://scratch.mit.edu/), [Lua](https://www.lua.org/start.html), [LÖVE](https://www.love2d.org/), [Rust](https://www.rust-lang.org/) and [Zig](https://ziglang.org/). A great first language and a great next language to learn after Scratch. It will introduce low level concepts such as floating point numbers and bitwise operations.
# Goals
- simplicity
> [!NOTE]
> 1. It's hard to know if something is a function or method
>  - Only functions
> 3. There are too many implicit number rules
>  - Have one integer type
>  - Have one integer type and one byte type
>  - Have a integer type which is a collective name for all integers
>  - Explicit number conversion

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
```
+,-,/,*
i64 random_i64(i64 min, i64 max)
f64 random_f64(f64 min, f64 max)
>,>=,<=,<
and, or, not
i64 mod_i64(i64 x, i64 y)
i64 mod_f64(f64 x, f64 y)
i64 div_i64(i64 x, i64 y) // Crashes if y is equal to zero
i64 abs_i64(i64 x)

// All floating point functions crash if the input is infinity or nan. Use these functions to check for those cases:
bool is_nan(f64 x)
bool is_inifnity(f64 x)

f64 abs_f64(f64 x)
i64 round(f64 x)
i64 floor(f64 x)
i64 ceil(f64 x)
f64 sqrt(f64 x)
f64 sin(f64 x)
f64 cos(f64 x)
f64 tan(f64 x) // Crashes if the cosine of the input is zero
f64 arcsin(f64 x)
f64 arccos(f64 x)
f64 arctan(f64 x)
f64 ln(f64 x) // Crashes if the input is equal to or less than zero
f64 exp(f64 x)

i64 xor(i64 x, i64 y)
i64 and(i64 x, i64 y)
i64 or(i64 x, i64 y)
i64 not(i64 x)
i64 shift(i64 x, i8 shift)
```
# Lists
```
list1 = [1, 3, -3, 7]
list2 = "Hello, World!"

push(any item)
any pull() // Crashes if the list is empty
set(i64 index, any item) // Crashes if the index does not exist
remove(i64 index) // Crashes if the index does not exist?
clear()
insert(any item, i64 index) 
replace(any old, any new)
i64 index(any item) // Crashes if the item does not exist
i64 length()
bool contains(item)
[any] join([any] other)
[any] clone()
[any] repeat(i64 times)
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
i32 get_volume()
set_volume(i32 vol)
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
bool has_write_access(path)
bool has_read_access(path)
[i8] read(path) // Crashes if we don't have access
write([i8] path, [i8] content) // Crashes if we don't have access
i64 parse_i64([i8] text)
f64 parse_f64([i8] text)
[i8] format(any value)
print([i8] text)
[i8] input()
[[i8]] command_line_arguments()
```
# Debugging
```
assert(bool condition)
debug(any value)
```
