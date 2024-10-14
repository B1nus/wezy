# cb

- Indexing on slices and arithmetic operations return errors as values.
- Indexing into array with known size is bounds checked at compile time.
- arithmetic operations known at compile time are checked for errors at compile time.
- undefined. (pinky promise I wont forget)
- bounds check: if end of range is more than or equal to length of slice.
