(define (square x)
 (* x x))

(define (average x y)
  (/ (+ x y) 2))

(define (fib-iter a b count)
  (if (= count 0)
       b
      (fib-iter (+ a b) a (- count 1))))

(define (fact-iter product counter max-count)
        (if (> counter max-count)
            product
            (fact-iter (* counter product)
                       (+ counter 1)
                        max-count)))
