(module
    (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
    (import "wasi_snapshot_preview1" "proc_exit" (func $proc_exit (param i32)))

    (memory (export "memory") 1)

    (func $main (export "_start")
        (call $print_i64 (i64.const 111))
        (call $print_i64 (i64.const 222))
        (call $print_i64 (i64.const 333))
        (call $proc_exit (i32.const 0))
    )

    (func $print_i64 (param $x i64)
        (local $pos i32)
        (local $len i32)
        (local.set $pos (i32.const 1000))

        (local.set $len (i32.const 0))
        (loop $digits
          (i32.store8 (i32.sub (local.get $pos) (local.get $len)) (i32.add (i32.wrap_i64 (i64.rem_s (local.get $x) (i64.const 10))) (i32.const 48)))
          (local.set $x (i64.div_s (local.get $x) (i64.const 10)))
          (local.set $len (i32.add (local.get $len) (i32.const 1)))
          (br_if $digits (i64.ne (local.get $x) (i64.const 0)))
        )
        (local.set $pos (i32.sub (i32.add (local.get $pos) (i32.const 1)) (local.get $len)))

        ;; Data vector, we only have one. It consists of two words: the address
        ;; of our string, and its length.
        (i32.store (i32.const 0) (local.get $pos))
        (i32.store (i32.const 4) (local.get $len))

        (call $fd_write
            (i32.const 1) ;; 1 for stdout
            (i32.const 0)
            (i32.const 1)
            (i32.const 100) ;; write at memory position 100
        )
        drop
    )
)
