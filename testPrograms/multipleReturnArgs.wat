(module
    (func $print (import "imports" "print") (param i32))
    (func $gc (import "imports" "gc") (param i32))
    (import "js" "mem" (memory 1))
    (type $basicFunc (func))
    (data (i32.const 4) "print")
(data (i32.const 16) "_G")

    (global $HP (export "HP") (mut i32) (i32.const 20))
    (global $FP (export "FP") (mut i32) (i32.const 20))
    (global $SP (export "SP") (mut i32) (i32.const 65528))
    (global $temp (mut i32) (i32.const 0))
    (func $equals (param $lhs i32) (param $rhs i32) (result i32)
    (local $lhsStringPtr i32) (local $rhsStringPtr i32) (local $i i32)

      ;; If the types are different, return false
      (i32.ne
        (i32.load (local.get $lhs))
        (i32.load (local.get $rhs))
      )
      (if (then (return (i32.const 0))))
      ;; If the types not a string, just compare the pointer/int/bool/nil value
      (i32.ne
        (i32.load (local.get $lhs))
        (i32.const 4)
      )
      (if (then (return
        (i32.eq
          (i32.load (i32.add (i32.const 4) (local.get $lhs)))
          (i32.load (i32.add (i32.const 4) (local.get $rhs)))
        )
      )))
      ;; Otherwise, must compare strings
      (local.set $lhsStringPtr (i32.load (i32.add (i32.const 4) (local.get $lhs))))
      (local.set $rhsStringPtr (i32.load (i32.add (i32.const 4) (local.get $rhs))))
      ;; If the strings are of different length, return false
      (i32.ne (i32.load (local.get $lhsStringPtr)) (i32.load (local.get $rhsStringPtr)))
      (if (then
        (return (i32.const 0))
      ))

      (local.set $i (i32.const 4))
      ;; Must compare each of the lengths
      (loop
        (i32.ne
          (i32.load
            (i32.add
              (local.get $lhsStringPtr)
              (local.get $i)
            )
          )
          (i32.load
            (i32.add
              (local.get $rhsStringPtr)
              (local.get $i)
            )
          )
        )
        ;; If the characters aren't the same return 0
        (if (then (return (i32.const 0))))
        ;; Increment i
        (local.set $i (i32.add (local.get $i) (i32.const 4)))
        ;; Loop if i less than string length
        (br_if
          0
          (i32.lt_s
            (i32.sub (local.get $i) (i32.const 4))
            (i32.load (local.get $lhsStringPtr))
          )
        )
      )

      (return (i32.const 1))
    )
    (func $nearestPrime (param $n i32) (result i32)
      (local $cd i32)
      (loop $notPrime
        ;; Increment n by 1
        (local.set $n (i32.add (local.get $n) (i32.const 1)))
        ;; Reset candidate divisor
        (local.set $cd (i32.const 1))
        (block $foundPrime
          (loop $nextCd
            (local.set $cd (i32.add (local.get $cd) (i32.const 1)))
            ;; If our candidate divisor divides evenly into n, then n is composite
            (i32.rem_s (local.get $n) (local.get $cd))
            i32.const 0
            i32.eq
            ;; So go to the next n
            br_if $notPrime

            ;; If candidate divisor is n-1, we've checked all possible divisors, we're good
            (i32.eq (local.get $cd) (i32.sub (local.get $n) (i32.const 1)))
            br_if $foundPrime
            ;; Otherwise, look at next candidate divisor
            br $nextCd
          )
        )
        (return (local.get $n))
      )
      ;; Cannot get here
      unreachable
    )
    (func $hashInsert (param $tablePtr i32) (param $keyPtr i32) (param $valuePtr i32)
      (local $kvpPtr i32)
      (local $numElementsPtr i32)
      (local $capacityPtr i32)

      (local.set $numElementsPtr (i32.load (i32.add (local.get $tablePtr) (i32.const 4))))
      (local.set $capacityPtr (i32.add (i32.const 4) (local.get $numElementsPtr)))

      (i32.store (local.get $numElementsPtr) (i32.add (i32.load (local.get $numElementsPtr)) (i32.const 1)))


      (call $maybeRehash (local.get $tablePtr))

      (local.set $kvpPtr
        (call $hashSearch
          (local.get $tablePtr)
          (local.get $keyPtr)
        )
      )

      (memory.copy
        (local.get $kvpPtr)
        (local.get $keyPtr)
        (i32.const 8)
      )

      (memory.copy
        (i32.add (i32.const 8) (local.get $kvpPtr))
        (local.get $valuePtr)
        (i32.const 8)
      )
    )

    (func $hashSearchArray (param $hashArrayBase i32) (param $hashSize i32) (param $keyPtr i32) (result i32)
    (local $hashIndex i32) (local $kvpPtr i32)

    (local.set $hashIndex (call $hashKey (local.get $keyPtr) (local.get $hashSize)))

    ;; Do linear probing

    (loop
      (local.set $kvpPtr
        (i32.add
          (local.get $hashArrayBase)
          (i32.mul (local.get $hashIndex) (i32.const 16))
        )
      )
      ;; If the key is nil, can place there
      (if
        (i32.eq
          (i32.load (local.get $kvpPtr))
          (i32.const 0)
        )
        (then
          (return (local.get $kvpPtr))
        )
      )
      ;; If the key matches, we've found it
      (if
        (call $equals
          (local.get $kvpPtr)
          (local.get $keyPtr)
        )
        (then (return (local.get $kvpPtr)))
      )
      ;; Otherwise, increment
      (local.set $hashIndex
        (i32.rem_s
          (i32.add
            (local.get $hashIndex)
            (i32.const 1)
          )
          (local.get $hashSize)
        )
      )
      br 0
    )

    unreachable)
    (func $hashSearch (param $tablePtr i32) (param $keyPtr i32) (result i32)
    (local $hashArrayBase i32) (local $hashSize i32)

    (local.set $hashArrayBase
      (i32.load
        (i32.add
          (i32.const 8)
          (i32.load
            (i32.add (i32.const 4) (local.get $tablePtr))
          )
        )
      )
    )

    (local.set $hashSize
      (i32.load
        (i32.add
          (i32.const 4)
          (i32.load
            (i32.add
              (i32.const 4)
              (local.get $tablePtr)
            )
          )
        )
      )
    )

    (call $hashSearchArray (local.get $hashArrayBase) (local.get $hashSize) (local.get $keyPtr))
    )
    (func $hashKey (param $keyptr i32) (param $modulus i32) (result i32)
      (local $stringLocation i32) (local $stringCharacters i32) (local $stringResult i32) (local $loopParam i32)
      (local $curChar i32)
      (i32.ne (i32.load (local.get $keyptr)) (i32.const 4))
      (if (then (return
        (i32.rem_s
          (i32.load
            (i32.add
              (i32.const 4)
              (local.get $keyptr)
            )
          )
          (local.get $modulus)
        )
      )))
      ;; Hashing string requires more complex approach

      (local.set $stringLocation (i32.load (i32.add (i32.const 4) (local.get $keyptr))))

      (local.set
        $stringCharacters
        (i32.load (local.get $stringLocation))
      )
      (local.set $loopParam (i32.const 0))
      (local.set $stringResult (i32.const 0))
      (loop
        (local.set $curChar
          (i32.load8_u
            (i32.add
              (local.get $stringLocation)
              (i32.add (local.get $loopParam) (i32.const 4))
            )
          )
        )

        (local.set $stringResult
          (i32.rem_s
            (i32.add
              (local.get $stringResult)
              (i32.mul
                (local.get $curChar)
                (i32.const 257)
              )
            )
            (local.get $modulus)
          )
        )

        (local.set $loopParam
          (i32.add
            (local.get $loopParam)
            (i32.const 1)
          )
        )
        (br_if
          0
          (i32.lt_s
            (local.get $loopParam)
            (local.get $stringCharacters)
          )
        )
      )
      (local.get $stringResult)
    )
    (func $rehash (param $tablePtr i32)
      (local $currentHashCapacity i32) (local $newHashArrayBytes i32) (local $loopParam i32)
      (local $elementsInserted i32)
      (local $hashTableBase i32)
      (local $oldHashArrayPtr i32)
      (local $kvpPtr i32)
      (local $newHashCapacity i32) (local $newHashArrayPtr i32)

      (local.set $hashTableBase
        (i32.load (i32.add (i32.const 4) (local.get $tablePtr)))
      )
      (local.set $currentHashCapacity
        (i32.load
          (i32.add
            (i32.const 4)
            (local.get $hashTableBase)
          )
        )
      )

      (local.set $newHashCapacity
        (call $nearestPrime
          (i32.mul
            (i32.const 2)
            (local.get $currentHashCapacity)
          )
        )
      )

      (local.set $newHashArrayBytes (i32.mul (local.get $newHashCapacity) (i32.const 16)))

      (call $alloc (local.get $newHashArrayBytes))
      (local.set $newHashArrayPtr (i32.sub (global.get $HP) (local.get $newHashArrayBytes)))
      (local.set $oldHashArrayPtr (i32.load (i32.add (local.get $hashTableBase) (i32.const 8))))

      (local.set $elementsInserted (i32.const 0))
      (local.set $loopParam (i32.const 0))
      (loop
        (local.set $kvpPtr (i32.add (local.get $oldHashArrayPtr) (i32.mul (i32.const 16) (local.get $loopParam))))
        (if
          ;; If the key isn't nil, and the value isn't nil, insert it
          (i32.and
            (i32.ne
              (i32.load (local.get $kvpPtr))
              (i32.const 0)
            )
            (i32.ne
              (i32.load (i32.add (i32.const 8) (local.get $kvpPtr)))
              (i32.const 0)
            )
          )
          (then
            (memory.copy
              (call $hashSearchArray (local.get $newHashArrayPtr) (local.get $newHashCapacity) (local.get $kvpPtr))
              (local.get $kvpPtr)
              (i32.const 16)
            )
            (local.set $elementsInserted (i32.add (local.get $elementsInserted) (i32.const 1)))
          )
        )

        (local.set $loopParam (i32.add (local.get $loopParam) (i32.const 1)))
        (br_if 0 (i32.lt_s (local.get $loopParam) (local.get $currentHashCapacity)))
      )

      (i32.store (local.get $hashTableBase) (local.get $elementsInserted))
      (i32.store (i32.add (i32.const 4) (local.get $hashTableBase)) (local.get $newHashCapacity))
      (i32.store (i32.add (i32.const 8) (local.get $hashTableBase)) (local.get $newHashArrayPtr))
    )
    (func $maybeRehash (param $tablePtr i32)
      (local $numElementsPtr i32)
      (local $capacityPtr i32)

      (local.set $numElementsPtr (i32.load (i32.add (local.get $tablePtr) (i32.const 4))))
      (local.set $capacityPtr (i32.add (i32.const 4) (local.get $numElementsPtr)))

      (if
        (i32.gt_s
          (i32.load (local.get $numElementsPtr))
          (i32.div_s (i32.load (local.get $capacityPtr)) (i32.const 2))
        )
        (then
          (call $rehash (local.get $tablePtr))
        )
      )
    )
    (func $alloc (param $bytes i32)
      (call $gc (local.get $bytes))
      (global.set $HP
        (i32.add
          (global.get $HP)
          (local.get $bytes)
        )
      )
    )
    (table 9 funcref)
    (elem (i32.const 0) $f0 $f1 $f2 $f3 $f4 $f5 $f6 $f7 $f8 )
(func $f0 (export "main")
 (i32.store (i32.const 0) (i32.const 5))
 (i32.store (i32.const 12) (i32.const 2))
 (i32.store (global.get $FP) (i32.const -1))
 (i32.store (i32.add (i32.const 4) (global.get $FP)) (i32.const -1))
 (i32.store (i32.add (i32.const 8) (global.get $FP)) (i32.const 7))
 (global.set $HP (i32.add (global.get $HP) (i32.const 68)))
 (call $alloc (i32.add (i32.const 12) (i32.const 176)))
 (i32.store (i32.sub (global.get $HP) (i32.add (i32.const 12) (i32.const 176))) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.add (i32.const 12) (i32.const 176)))) (i32.const 11))
 (i32.store (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.add (i32.const 12) (i32.const 176)))) (i32.sub (global.get $HP) (i32.const 176)))
 (memory.fill
  (i32.sub (global.get $HP) (i32.const 176))
  (i32.const 0)
  (i32.const 176)
  )
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.add (i32.const 12) (i32.const 176))))
 (i32.store (global.get $SP) (i32.const 6))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (global.set $SP (i32.add (global.get $SP) (i32.const 0)))
 (memory.copy
  (i32.add (global.get $FP) (i32.const 12))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 12)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 16)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 0))
 (i32.store (global.get $SP) (i32.const 4))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (global.set $SP (i32.add (global.get $SP) (i32.const 16)))
 (i32.store
  (i32.load (i32.add (i32.const 4) (global.get $SP)))
  (i32.add
   (i32.load (i32.load (i32.add (i32.const 4) (global.get $SP))))
   (i32.const 1)
   )
  )
 (call $maybeRehash (global.get $SP))
 (memory.copy
  (call $hashSearch
   (global.get $SP)
   (i32.sub (global.get $SP) (i32.const 8))
   )
  (i32.sub (global.get $SP) (i32.const 8))
  (i32.const 8)
  )
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.add
   (i32.const 8)
   (call $hashSearch
    (global.get $SP)
    (i32.sub (global.get $SP) (i32.const 8))
    )
   ))
 (i32.store (global.get $SP) (i32.const 8))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 8))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 1))
 (i32.sub (global.get $HP) (i32.const 4))
 global.get $FP
 i32.store
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 8)))
 (i32.store (global.get $SP) (i32.const 5))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.load
   (i32.add
    (global.get $SP)
    (i32.const 20)
    )
   )
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 16)))
 global.get $SP
 global.get $FP
 (i32.const 12)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 16)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 12))
 (i32.store (global.get $SP) (i32.const 4))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (global.set $SP (i32.add (global.get $SP) (i32.const 16)))
 (i32.store
  (i32.load (i32.add (i32.const 4) (global.get $SP)))
  (i32.add
   (i32.load (i32.load (i32.add (i32.const 4) (global.get $SP))))
   (i32.const 1)
   )
  )
 (call $maybeRehash (global.get $SP))
 (memory.copy
  (call $hashSearch
   (global.get $SP)
   (i32.sub (global.get $SP) (i32.const 8))
   )
  (i32.sub (global.get $SP) (i32.const 8))
  (i32.const 8)
  )
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.add
   (i32.const 8)
   (call $hashSearch
    (global.get $SP)
    (i32.sub (global.get $SP) (i32.const 8))
    )
   ))
 (i32.store (global.get $SP) (i32.const 8))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 12)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 16)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.load
   (i32.add
    (global.get $SP)
    (i32.const 20)
    )
   )
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 16)))
 (call $alloc (i32.const 8))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 2))
 (i32.sub (global.get $HP) (i32.const 4))
 global.get $FP
 i32.store
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 8)))
 (i32.store (global.get $SP) (i32.const 5))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $FP) (i32.const 20))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 8))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 4))
 (i32.sub (global.get $HP) (i32.const 4))
 global.get $FP
 i32.store
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 8)))
 (i32.store (global.get $SP) (i32.const 5))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $FP) (i32.const 28))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 8))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 5))
 (i32.sub (global.get $HP) (i32.const 4))
 global.get $FP
 i32.store
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 8)))
 (i32.store (global.get $SP) (i32.const 5))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $FP) (i32.const 36))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 8))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 6))
 (i32.sub (global.get $HP) (i32.const 4))
 global.get $FP
 i32.store
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 8)))
 (i32.store (global.get $SP) (i32.const 5))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $FP) (i32.const 44))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 8))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 7))
 (i32.sub (global.get $HP) (i32.const 4))
 global.get $FP
 i32.store
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 8)))
 (i32.store (global.get $SP) (i32.const 5))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $FP) (i32.const 52))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 8))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 8))
 (i32.sub (global.get $HP) (i32.const 4))
 global.get $FP
 i32.store
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 8)))
 (i32.store (global.get $SP) (i32.const 5))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $FP) (i32.const 60))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 60)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 64)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 28)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 32)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 0))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 20)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 28)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 60)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 64)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 36)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 40)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 0))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 20)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 28)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 60)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 64)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 44)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 48)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 0))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 20)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 28)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 60)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 64)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 52)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 56)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 0))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 20)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 28)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )


(func $f1
 (call $alloc (i32.const 20))
 (i32.store (i32.sub (global.get $HP) (i32.const 20)) (i32.load (i32.add (i32.const 4) (i32.load
     (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul
        (i32.const 8)
        (i32.load (i32.add (i32.const 12) (global.get $SP)))
        )
       (i32.const 20)
       )
      )
     ))))
 (i32.store
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 20)))
  (global.get $FP)
  )
 (i32.store
  (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.const 20)))
  (i32.const 1)
  )
 (global.set $FP (i32.sub (global.get $HP) (i32.const 20)))
 (i32.lt_s (i32.const 0) (i32.sub (i32.load (i32.add (i32.const 12) (global.get $SP))) (i32.const 1)))
 (if (then
   (memory.copy
    (i32.add
     (global.get $FP)
     (i32.const 12)
     )
    (i32.sub (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
       (i32.const 8)
       )
      ) (i32.const 0))
    (i32.const 8)
    )
   ) (else
   (i32.eq (i32.load (i32.add (global.get $SP) (i32.const 16))) (i32.const 7))
   (if (then
     (i32.gt_s (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))) (i32.const 0))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.add
         (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
         (i32.add
          (i32.mul
           (i32.sub
            (i32.const 1)
            (i32.load (i32.add (i32.const 12) (global.get $SP)))
            )
           (i32.const 8)
           )
          (i32.const 4)
          )
         )
        (i32.const 8)
        )
       (i32.store
        (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
        (i32.sub
         (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4))))
         (i32.const 1)
         )
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ) (else
     (i32.eq (i32.const 1) (i32.load (i32.add (i32.const 12) (global.get $SP))))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.sub (i32.add
          (global.get $SP)
          (i32.add
           (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
           (i32.const 8)
           )
          ) (i32.const 0))
        (i32.const 8)
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ))
   ))
 (global.set $SP
  (i32.add
   (global.get $SP)
   (i32.add
    (i32.const 16)
    (i32.mul
     (i32.const 8)
     (i32.load (i32.add (i32.const 12) (global.get $SP)))
     )
    )
   )
  )

 (call $print (i32.add (global.get $FP) (i32.const 12)))

 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )


(func $f2
 (call $alloc (i32.const 28))
 (i32.store (i32.sub (global.get $HP) (i32.const 28)) (i32.load (i32.add (i32.const 4) (i32.load
     (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul
        (i32.const 8)
        (i32.load (i32.add (i32.const 12) (global.get $SP)))
        )
       (i32.const 20)
       )
      )
     ))))
 (i32.store
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 28)))
  (global.get $FP)
  )
 (i32.store
  (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.const 28)))
  (i32.const 2)
  )
 (global.set $FP (i32.sub (global.get $HP) (i32.const 28)))
 (i32.lt_s (i32.const 0) (i32.sub (i32.load (i32.add (i32.const 12) (global.get $SP))) (i32.const 1)))
 (if (then
   (memory.copy
    (i32.add
     (global.get $FP)
     (i32.const 12)
     )
    (i32.sub (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
       (i32.const 8)
       )
      ) (i32.const 0))
    (i32.const 8)
    )
   ) (else
   (i32.eq (i32.load (i32.add (global.get $SP) (i32.const 16))) (i32.const 7))
   (if (then
     (i32.gt_s (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))) (i32.const 0))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.add
         (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
         (i32.add
          (i32.mul
           (i32.sub
            (i32.const 1)
            (i32.load (i32.add (i32.const 12) (global.get $SP)))
            )
           (i32.const 8)
           )
          (i32.const 4)
          )
         )
        (i32.const 8)
        )
       (i32.store
        (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
        (i32.sub
         (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4))))
         (i32.const 1)
         )
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ) (else
     (i32.eq (i32.const 1) (i32.load (i32.add (i32.const 12) (global.get $SP))))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.sub (i32.add
          (global.get $SP)
          (i32.add
           (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
           (i32.const 8)
           )
          ) (i32.const 0))
        (i32.const 8)
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ))
   ))
 (global.set $SP
  (i32.add
   (global.get $SP)
   (i32.add
    (i32.const 16)
    (i32.mul
     (i32.const 8)
     (i32.load (i32.add (i32.const 12) (global.get $SP)))
     )
    )
   )
  )
 (call $alloc (i32.const 8))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 3))
 (i32.sub (global.get $HP) (i32.const 4))
 global.get $FP
 i32.store
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 8)))
 (i32.store (global.get $SP) (i32.const 5))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $FP) (i32.const 20))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 20)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 24)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 12)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 16)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 0))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 28))
 (global.set $temp (i32.sub (global.get $HP) (i32.const 28)))
 (i32.store (i32.sub (global.get $HP) (i32.const 28)) (i32.const 3))
 (memory.copy
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 28)))
  (i32.add (global.get $SP) (i32.const 24))
  (i32.const 8)
  )
 (memory.copy
  (i32.add (i32.const 12) (i32.sub (global.get $HP) (i32.const 28)))
  (i32.add (global.get $SP) (i32.const 16))
  (i32.const 8)
  )
 (memory.copy
  (i32.add (i32.const 20) (i32.sub (global.get $HP) (i32.const 28)))
  (i32.add (global.get $SP) (i32.const 8))
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 24)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (global.get $temp))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 return
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )


(func $f3
 (call $alloc (i32.const 36))
 (i32.store (i32.sub (global.get $HP) (i32.const 36)) (i32.load (i32.add (i32.const 4) (i32.load
     (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul
        (i32.const 8)
        (i32.load (i32.add (i32.const 12) (global.get $SP)))
        )
       (i32.const 20)
       )
      )
     ))))
 (i32.store
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 36)))
  (global.get $FP)
  )
 (i32.store
  (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.const 36)))
  (i32.const 3)
  )
 (global.set $FP (i32.sub (global.get $HP) (i32.const 36)))
 (i32.lt_s (i32.const 0) (i32.sub (i32.load (i32.add (i32.const 12) (global.get $SP))) (i32.const 1)))
 (if (then
   (memory.copy
    (i32.add
     (global.get $FP)
     (i32.const 12)
     )
    (i32.sub (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
       (i32.const 8)
       )
      ) (i32.const 0))
    (i32.const 8)
    )
   ) (else
   (i32.eq (i32.load (i32.add (global.get $SP) (i32.const 16))) (i32.const 7))
   (if (then
     (i32.gt_s (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))) (i32.const 0))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.add
         (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
         (i32.add
          (i32.mul
           (i32.sub
            (i32.const 1)
            (i32.load (i32.add (i32.const 12) (global.get $SP)))
            )
           (i32.const 8)
           )
          (i32.const 4)
          )
         )
        (i32.const 8)
        )
       (i32.store
        (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
        (i32.sub
         (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4))))
         (i32.const 1)
         )
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ) (else
     (i32.eq (i32.const 1) (i32.load (i32.add (i32.const 12) (global.get $SP))))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.sub (i32.add
          (global.get $SP)
          (i32.add
           (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
           (i32.const 8)
           )
          ) (i32.const 0))
        (i32.const 8)
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ))
   ))
 (i32.lt_s (i32.const 1) (i32.sub (i32.load (i32.add (i32.const 12) (global.get $SP))) (i32.const 1)))
 (if (then
   (memory.copy
    (i32.add
     (global.get $FP)
     (i32.const 20)
     )
    (i32.sub (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
       (i32.const 8)
       )
      ) (i32.const 8))
    (i32.const 8)
    )
   ) (else
   (i32.eq (i32.load (i32.add (global.get $SP) (i32.const 16))) (i32.const 7))
   (if (then
     (i32.gt_s (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))) (i32.const 0))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 20)
         )
        (i32.add
         (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
         (i32.add
          (i32.mul
           (i32.sub
            (i32.const 2)
            (i32.load (i32.add (i32.const 12) (global.get $SP)))
            )
           (i32.const 8)
           )
          (i32.const 4)
          )
         )
        (i32.const 8)
        )
       (i32.store
        (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
        (i32.sub
         (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4))))
         (i32.const 1)
         )
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 20)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ) (else
     (i32.eq (i32.const 2) (i32.load (i32.add (i32.const 12) (global.get $SP))))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 20)
         )
        (i32.sub (i32.add
          (global.get $SP)
          (i32.add
           (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
           (i32.const 8)
           )
          ) (i32.const 8))
        (i32.const 8)
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 20)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ))
   ))
 (global.set $SP
  (i32.add
   (global.get $SP)
   (i32.add
    (i32.const 16)
    (i32.mul
     (i32.const 8)
     (i32.load (i32.add (i32.const 12) (global.get $SP)))
     )
    )
   )
  )
 (i32.store (global.get $SP) (i32.const 8))
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 20)
 i32.add
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 20)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 24)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.add (i32.const 20) (global.get $SP))
 (i32.load (i32.add (global.get $SP) (i32.const 20)))
 (i32.load (i32.add (global.get $SP) (i32.const 12)))
 (i32.store (i32.add (i32.const 16) (global.get $SP)) (i32.const 1))
 i32.add
 i32.store
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.load
   (i32.add
    (global.get $SP)
    (i32.const 20)
    )
   )
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 16)))
 global.get $SP
 global.get $FP
 (i32.const 12)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 16)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 20)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 24)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $SP) (i32.const 8))
  (i32.add
   (i32.const 8)
   (call $hashSearch
    (i32.add
     (global.get $SP)
     (i32.const 8)
     )
    (global.get $SP)
    )
   )
  (i32.const 8)
  )
 (memory.copy
  (i32.add (global.get $FP) (i32.const 28))
  (i32.add
   (i32.const 8)
   (global.get $SP)
   )
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 (i32.const 28)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 32)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (i32.and
  (i32.ne
   (i32.load (global.get $SP))
   (i32.const 0)
   )
  (i32.or
   (i32.ne
    (i32.load (global.get $SP))
    (i32.const 3)
    )
   (i32.ne (i32.load (i32.add (global.get $SP) (i32.const 4))) (i32.const 0))
   )
  )

 (if (then
   global.get $SP
   global.get $FP
   (i32.const 20)
   i32.add
   i32.load
   i32.store
   (i32.add (global.get $SP) (i32.const 4))
   global.get $FP
   (i32.const 24)
   i32.add
   i32.load
   i32.store
   (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
   global.get $SP
   global.get $FP
   (i32.const 28)
   i32.add
   i32.load
   i32.store
   (i32.add (global.get $SP) (i32.const 4))
   global.get $FP
   (i32.const 32)
   i32.add
   i32.load
   i32.store
   (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
   (call $alloc (i32.const 20))
   (global.set $temp (i32.sub (global.get $HP) (i32.const 20)))
   (i32.store (i32.sub (global.get $HP) (i32.const 20)) (i32.const 2))
   (memory.copy
    (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 20)))
    (i32.add (global.get $SP) (i32.const 16))
    (i32.const 8)
    )
   (memory.copy
    (i32.add (i32.const 12) (i32.sub (global.get $HP) (i32.const 20)))
    (i32.add (global.get $SP) (i32.const 8))
    (i32.const 8)
    )
   (global.set $SP (i32.add (global.get $SP) (i32.const 16)))
   (i32.store (i32.add (i32.const 4) (global.get $SP)) (global.get $temp))
   (i32.store (global.get $SP) (i32.const 7))
   (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
   return
   ) (else
   ))
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )


(func $f4
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.load (i32.add (i32.const 4) (i32.load
     (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul
        (i32.const 8)
        (i32.load (i32.add (i32.const 12) (global.get $SP)))
        )
       (i32.const 20)
       )
      )
     ))))
 (i32.store
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 12)))
  (global.get $FP)
  )
 (i32.store
  (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.const 12)))
  (i32.const 0)
  )
 (global.set $FP (i32.sub (global.get $HP) (i32.const 12)))
 (global.set $SP
  (i32.add
   (global.get $SP)
   (i32.add
    (i32.const 16)
    (i32.mul
     (i32.const 8)
     (i32.load (i32.add (i32.const 12) (global.get $SP)))
     )
    )
   )
  )
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )


(func $f5
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.load (i32.add (i32.const 4) (i32.load
     (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul
        (i32.const 8)
        (i32.load (i32.add (i32.const 12) (global.get $SP)))
        )
       (i32.const 20)
       )
      )
     ))))
 (i32.store
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 12)))
  (global.get $FP)
  )
 (i32.store
  (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.const 12)))
  (i32.const 0)
  )
 (global.set $FP (i32.sub (global.get $HP) (i32.const 12)))
 (global.set $SP
  (i32.add
   (global.get $SP)
   (i32.add
    (i32.const 16)
    (i32.mul
     (i32.const 8)
     (i32.load (i32.add (i32.const 12) (global.get $SP)))
     )
    )
   )
  )
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 12))
 (global.set $temp (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (memory.copy
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 12)))
  (i32.add (global.get $SP) (i32.const 8))
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (global.get $temp))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 return
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )


(func $f6
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.load (i32.add (i32.const 4) (i32.load
     (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul
        (i32.const 8)
        (i32.load (i32.add (i32.const 12) (global.get $SP)))
        )
       (i32.const 20)
       )
      )
     ))))
 (i32.store
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 12)))
  (global.get $FP)
  )
 (i32.store
  (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.const 12)))
  (i32.const 0)
  )
 (global.set $FP (i32.sub (global.get $HP) (i32.const 12)))
 (global.set $SP
  (i32.add
   (global.get $SP)
   (i32.add
    (i32.const 16)
    (i32.mul
     (i32.const 8)
     (i32.load (i32.add (i32.const 12) (global.get $SP)))
     )
    )
   )
  )
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 2))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 20))
 (global.set $temp (i32.sub (global.get $HP) (i32.const 20)))
 (i32.store (i32.sub (global.get $HP) (i32.const 20)) (i32.const 2))
 (memory.copy
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 20)))
  (i32.add (global.get $SP) (i32.const 16))
  (i32.const 8)
  )
 (memory.copy
  (i32.add (i32.const 12) (i32.sub (global.get $HP) (i32.const 20)))
  (i32.add (global.get $SP) (i32.const 8))
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 16)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (global.get $temp))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 return
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )


(func $f7
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.load (i32.add (i32.const 4) (i32.load
     (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul
        (i32.const 8)
        (i32.load (i32.add (i32.const 12) (global.get $SP)))
        )
       (i32.const 20)
       )
      )
     ))))
 (i32.store
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 12)))
  (global.get $FP)
  )
 (i32.store
  (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.const 12)))
  (i32.const 0)
  )
 (global.set $FP (i32.sub (global.get $HP) (i32.const 12)))
 (global.set $SP
  (i32.add
   (global.get $SP)
   (i32.add
    (i32.const 16)
    (i32.mul
     (i32.const 8)
     (i32.load (i32.add (i32.const 12) (global.get $SP)))
     )
    )
   )
  )
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 2))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 3))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 28))
 (global.set $temp (i32.sub (global.get $HP) (i32.const 28)))
 (i32.store (i32.sub (global.get $HP) (i32.const 28)) (i32.const 3))
 (memory.copy
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 28)))
  (i32.add (global.get $SP) (i32.const 24))
  (i32.const 8)
  )
 (memory.copy
  (i32.add (i32.const 12) (i32.sub (global.get $HP) (i32.const 28)))
  (i32.add (global.get $SP) (i32.const 16))
  (i32.const 8)
  )
 (memory.copy
  (i32.add (i32.const 20) (i32.sub (global.get $HP) (i32.const 28)))
  (i32.add (global.get $SP) (i32.const 8))
  (i32.const 8)
  )
 (global.set $SP (i32.add (global.get $SP) (i32.const 24)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (global.get $temp))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 return
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )


(func $f8
 (call $alloc (i32.const 28))
 (i32.store (i32.sub (global.get $HP) (i32.const 28)) (i32.load (i32.add (i32.const 4) (i32.load
     (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul
        (i32.const 8)
        (i32.load (i32.add (i32.const 12) (global.get $SP)))
        )
       (i32.const 20)
       )
      )
     ))))
 (i32.store
  (i32.add (i32.const 4) (i32.sub (global.get $HP) (i32.const 28)))
  (global.get $FP)
  )
 (i32.store
  (i32.add (i32.const 8) (i32.sub (global.get $HP) (i32.const 28)))
  (i32.const 2)
  )
 (global.set $FP (i32.sub (global.get $HP) (i32.const 28)))
 (i32.lt_s (i32.const 0) (i32.sub (i32.load (i32.add (i32.const 12) (global.get $SP))) (i32.const 1)))
 (if (then
   (memory.copy
    (i32.add
     (global.get $FP)
     (i32.const 12)
     )
    (i32.sub (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
       (i32.const 8)
       )
      ) (i32.const 0))
    (i32.const 8)
    )
   ) (else
   (i32.eq (i32.load (i32.add (global.get $SP) (i32.const 16))) (i32.const 7))
   (if (then
     (i32.gt_s (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))) (i32.const 0))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.add
         (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
         (i32.add
          (i32.mul
           (i32.sub
            (i32.const 1)
            (i32.load (i32.add (i32.const 12) (global.get $SP)))
            )
           (i32.const 8)
           )
          (i32.const 4)
          )
         )
        (i32.const 8)
        )
       (i32.store
        (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
        (i32.sub
         (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4))))
         (i32.const 1)
         )
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ) (else
     (i32.eq (i32.const 1) (i32.load (i32.add (i32.const 12) (global.get $SP))))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.sub (i32.add
          (global.get $SP)
          (i32.add
           (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
           (i32.const 8)
           )
          ) (i32.const 0))
        (i32.const 8)
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 12)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ))
   ))
 (i32.lt_s (i32.const 1) (i32.sub (i32.load (i32.add (i32.const 12) (global.get $SP))) (i32.const 1)))
 (if (then
   (memory.copy
    (i32.add
     (global.get $FP)
     (i32.const 20)
     )
    (i32.sub (i32.add
      (global.get $SP)
      (i32.add
       (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
       (i32.const 8)
       )
      ) (i32.const 8))
    (i32.const 8)
    )
   ) (else
   (i32.eq (i32.load (i32.add (global.get $SP) (i32.const 16))) (i32.const 7))
   (if (then
     (i32.gt_s (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))) (i32.const 0))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 20)
         )
        (i32.add
         (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
         (i32.add
          (i32.mul
           (i32.sub
            (i32.const 2)
            (i32.load (i32.add (i32.const 12) (global.get $SP)))
            )
           (i32.const 8)
           )
          (i32.const 4)
          )
         )
        (i32.const 8)
        )
       (i32.store
        (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4)))
        (i32.sub
         (i32.load (i32.load (i32.add (i32.add (global.get $SP) (i32.const 16)) (i32.const 4))))
         (i32.const 1)
         )
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 20)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ) (else
     (i32.eq (i32.const 2) (i32.load (i32.add (i32.const 12) (global.get $SP))))
     (if (then
       (memory.copy
        (i32.add
         (global.get $FP)
         (i32.const 20)
         )
        (i32.sub (i32.add
          (global.get $SP)
          (i32.add
           (i32.mul (i32.const 8) (i32.load (i32.add (i32.const 12) (global.get $SP))))
           (i32.const 8)
           )
          ) (i32.const 8))
        (i32.const 8)
        )
       ) (else
       (memory.fill
        (i32.add
         (global.get $FP)
         (i32.const 20)
         )
        (i32.const 0)
        (i32.const 8)
        )
       ))
     ))
   ))
 (global.set $SP
  (i32.add
   (global.get $SP)
   (i32.add
    (i32.const 16)
    (i32.mul
     (i32.const 8)
     (i32.load (i32.add (i32.const 12) (global.get $SP)))
     )
    )
   )
  )
 global.get $SP
 global.get $FP
 i32.load
 (i32.const 12)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 i32.load
 (i32.const 16)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 0))
 (i32.store (global.get $SP) (i32.const 4))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $SP) (i32.const 8))
  (i32.add
   (i32.const 8)
   (call $hashSearch
    (i32.add
     (global.get $SP)
     (i32.const 8)
     )
    (global.get $SP)
    )
   )
  (i32.const 8)
  )
 global.get $SP
 global.get $FP
 (i32.const 12)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 16)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 28)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 global.get $SP
 global.get $FP
 i32.load
 (i32.const 12)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 i32.load
 (i32.const 16)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 0))
 (i32.store (global.get $SP) (i32.const 4))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (memory.copy
  (i32.add (global.get $SP) (i32.const 8))
  (i32.add
   (i32.const 8)
   (call $hashSearch
    (i32.add
     (global.get $SP)
     (i32.const 8)
     )
    (global.get $SP)
    )
   )
  (i32.const 8)
  )
 global.get $SP
 global.get $FP
 (i32.const 20)
 i32.add
 i32.load
 i32.store
 (i32.add (global.get $SP) (i32.const 4))
 global.get $FP
 (i32.const 24)
 i32.add
 i32.load
 i32.store
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.const 1))
 (i32.store (global.get $SP) (i32.const 1))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 (call_indirect
  (type $basicFunc)
  (i32.load
   (i32.load
    (i32.add
     (global.get $SP)
     (i32.const 28)
     )
    )
   )
  )
 (global.set $FP (i32.load (i32.add (global.get $FP) (i32.const 4))))
 (global.set $SP (i32.add (global.get $SP) (i32.const 8)))
 (call $alloc (i32.const 12))
 (i32.store (i32.sub (global.get $HP) (i32.const 12)) (i32.const 1))
 (i32.store (i32.sub (global.get $HP) (i32.const 8)) (i32.const 0))
 (i32.store (i32.sub (global.get $HP) (i32.const 4)) (i32.const 0))
 (i32.store (i32.add (i32.const 4) (global.get $SP)) (i32.sub (global.get $HP) (i32.const 12)))
 (i32.store (global.get $SP) (i32.const 7))
 (global.set $SP (i32.sub (global.get $SP) (i32.const 8)))
 )

)
