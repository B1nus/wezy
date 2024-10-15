# cb
The borrowchecker from rust with the simplicity of c.

# Main goals of cb
1. simplicity
2. simplicity
3. simplicity

- Indexing on slices and arithmetic operations return errors as values.
- Indexing into array with known size is bounds checked at compile time.
- arithmetic operations known at compile time are checked for errors at compile time.
- undefined. (pinky promise I wont forget)
- bounds check: if end of range is more than or equal to length of slice.

# Undefined
You can declare a variable without giving it a value. However, if the variable is used before getting a value a runtime error occurs. Think of it as a pinky promise that you will give the variable a value before using it:
```
int number

number = 2
print(number)
```

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
# Arithmetic

# Implicit error handling
Operations such as indexing a slice, and doing arithmetic with integers can cause errors to occur. (division by zero, integer overflow, index out-of-bounds). To avoid programmers from having to type `try` before all of these common operations, cb uses implicit error handling.

# Pointers
Pointer syntax is `*variable`. Dereference the pointer by removing the asterix `variable`.
# Memory management
cb handles memory management through a borrow checker [similar to rust](https://rustc-dev-guide.rust-lang.org/borrow_check.html). But before you get scared and run away, please note that cb's borrow checkear is simplier than rusts. cb's borrow checker does not have lifetimes and it only enforces a simple set of rules:
- You cannot use a moved variable
- You can not have a immutable reference while having a mutable reference
- ...
