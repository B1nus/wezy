(module
  (func $realloc (param i32 i32) (result i32)
    (memory.grow (i32.const 1))
    (drop)
    (memory.size)
  )
  (memory (export "memory") 1)
  (func (export "_start")
    i32.const 1
    i32.const 2
    (call $realloc)
    drop
  )
)
