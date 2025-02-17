# crust
Inspired by [Scratch](https://scratch.mit.edu/), [Lua](https://www.lua.org/start.html), [LÖVE](https://www.love2d.org/), [Rust](https://www.rust-lang.org/) and [Zig](https://ziglang.org/). A great first language, and a great next language to learn after Scratch. It will introduce low level concepts such as floating point numbers and bitwise operations.
# Goals
- simplicity
# Mvp
- only wasi
- only integers
# Error handling
Nope, it just crashes.
# Pointers
Nope.
# Mutability
Nope. Everything is mutable.
# Memory
Memory is deallocated once a variable goes ou of scope.
# Functions
All parameters are mutable references. Functions are strongly typed. Functions cannot use varibles from the outside, only their parameters. They can return mutliple values using tuples.
# Types
- We have 5 kinds of literals for numbers. Floats `1.0`, Integers `58`, Hexadecimal `0x4B`, Binary `0b01001011` and Bytes `'a'`. The Bytes value is the characters value in [ascii](https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fupload.wikimedia.org%2Fwikipedia%2Fcommons%2Fthumb%2Fd%2Fdd%2FASCII-Table.svg%2F2522px-ASCII-Table.svg.png&f=1&nofb=1&ipt=d06751b1640d9b550ceeb692df4b97fa295a63c012adbe3822e5ec24809bd801&ipo=images) and has the type `i8`.
- Integers can be any size that's an exponent of 2, `i8, i16, i32, i64, i128, i256, i512 ...`.
- floats have one size `f64` which is a 64-bit floating point number following the normal rules of [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754).
- Conversions are implicit. Use type declarations to convert between types. (`i64 x = 'a'`)
- Division always returns an `f64`. Use `div_i64()` for integer division.
- The type of an expression is the largest integer in the expression or `f64` if there is a float involved anywhere.
- Integer literals are assumed to be i64 unless given another type.
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
i64 div_i64(i64 x, i64 y)
i64 round(f64 x) // Crashes if the input is infinity or nan.
i64 floor(f64 x) // Crashes if the input is infinity or nan.
i64 ceil(f64 x) // Crashes if the input is infinity or nan.
i64 abs_i64(i64 x)
f64 abs_f64(f64 x)
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

push(item)
pull()
set(index, item) // Crashes if the index does not exist
remove(index) // Crashes if the index does not exist?
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
{[i8]:i32} map = {"you":10, "me":69}

set(key, value)
get(key)  // Crashes if the key does not exist
delete(key) // Crashes if the key does not exist=
clear()
value(key)
keys()
size()
has(key)
clone()
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
draw_image([i8] path, f64 x, f64 y, f64 rotation)
draw_triangle(f64 x1, f64 y1, f64 x2, f64 y2, f64 x3, f64 y3, f64 r, f64 g, f64 b, f64 a)

clear_canvas(f64 r, f64 g, f64 b)
(i32, i32) get_resolution()
```
# Audio
```
play([i8] path)
i32 get_volume()
set_volume(i32 vol)
```
# Input
```
(i32, i32) mouse_position()
bool mouse_pressed()
bool key_pressed(i8 key)

i64 nanoseconds_since_start()
i64 seconds_since_2000()
```
# Files
```
[i8] read(path)
write([i8] path, [i8] content)
i64 parse_i64([i8] text)
f64 parse_f64([i8] text)
[i8] format(any value)
print([i8] text)
[i8] input()
[[i8]] command_line_arguments()
```
