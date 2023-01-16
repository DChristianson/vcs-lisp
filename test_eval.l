; expressions for testing function evaluations

(define (f0)
 (+ 1 2))
 

(define (f1)
 (+ 1 (+ 1 (+ (+ 2 2) (+ 2 1)))))

(define (f1)
 (/ (+ 1 2) 2))

(define (f2)
  (* 2 (+ 1 2)))

(define (f3 x)
 (* x x))

(define (cube5 x)
 (* x x x x x))

(define (cube10 x)
 (* x x x x x x x x x x))

(define (cube31 x)
 (* x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x))


(define (biggest x)
  (+
    (+ 
      (+ 
        (+ x y z)
        (+ x y z)
        (+ x y z)
      ) 
      (+ 
        (+ x y z)
        (+ x y z)
        (+ x y z)
      )
      (+ 
        (+ x y z)
        (+ x y z)
        (+ x y z)
      )
    )
    (+
      (+ 
        (+ x y z)
        (+ x y z)
        (+ x y z)
      ) 
      (+ 
        (+ x y z)
        (+ x y z)
        (+ x y z)
      )
      (+ 
        (+ x y z)
        (+ x y z)
        (+ x y z)
      )
    )
 )
)