;; json.scm - JSON reader and writer
;; License:  Expat (MIT)
;; Homepage: https://notabug.org/pangolinturtle/json-r7rs

;; Copyright (c) 2011-2014 by Marc Feeley, All Rights Reserved.
;; Copyright (c) 2015 by Jason K. MacDuffie

;;;
;;;; --
;;;; json-null is implemented as a record type
;;;

(define-record-type json-null-type
  (make-json-null)
  json-null?)

(define json-null
  (let ((result (make-json-null)))
    (lambda () result)))

;;;
;;;; --
;;;; JSON reader
;;;

(define (json-read . port-option)
  (define port (if (null? port-option)
                   (current-input-port)
                   (if (null? (cdr port-option))
                       (car port-option)
                       (error "json-read" "Too many arguments"))))

  (define (create-object props)
    (alist->hash-table props eq?))

  (define (rd)
    (read-char port))

  (define (pk)
    (peek-char port))

  (define (accum c i str)
    (string-set! str i c)
    str)

  (define (digit? c radix)
    (and (char? c)
         (let ((n
                (cond ((and (char>=? c #\0) (char<=? c #\9))
                       (- (char->integer c) (char->integer #\0)))
                      ((and (char>=? c #\a) (char<=? c #\z))
                       (+ 10 (- (char->integer c) (char->integer #\a))))
                      ((and (char>=? c #\A) (char<=? c #\Z))
                       (+ 10 (- (char->integer c) (char->integer #\A))))
                      (else
                       999))))
           (and (< n radix)
                n))))

  (define (space)
    (let ((c (pk)))
      (if (and (char? c)
               (char<=? c #\space))
          (begin (rd) (space)))))

  (define (parse-value)
    (space)
    (let ((c (pk)))
      (if (not (char? c))
          (error "parse-value" "EOF while parsing")
          (cond ((eqv? c #\{)
                 (parse-object))
                ((eqv? c #\[)
                 (parse-array))
                ((eqv? c #\")
                 (parse-string))
                ((or (eqv? c #\-) (digit? c 10))
                 (parse-number))
                ((eqv? c #\f)
                 (rd)
                 (if (not (and (eqv? (rd) #\a)
                               (eqv? (rd) #\l)
                               (eqv? (rd) #\s)
                               (eqv? (rd) #\e)))
                     (error "parse-value" "Invalid literal")
                     #f))
                ((eqv? c #\t)
                 (rd)
                 (if (not (and (eqv? (rd) #\r)
                               (eqv? (rd) #\u)
                               (eqv? (rd) #\e)))
                     (error "parse-value" "Invalid literal")
                     #t))
                ((eqv? c #\n)
                 (rd)
                 (if (not (and (eqv? (rd) #\u)
                               (eqv? (rd) #\l)
                               (eqv? (rd) #\l)))
                     (error "parse-value" "Invalid literal")
                     (json-null)))
                (else
                 (error "parse-value" "JSON could not be decoded"))))))

  (define (parse-object)
    (rd) ;; skip #\{
    (space)
    (if (eqv? (pk) #\})
        (begin (rd) (create-object '()))
        (let loop ((rev-elements '()))
          (let ((str (if (not (eqv? (pk) #\"))
                         (error "parse-object" "Key did not begin with quote")
                         (parse-string))))
            (begin
              (space)
              (if (not (eqv? (pk) #\:))
                  (error "parse-object" "Key not followed by a colon")
                  (begin
                    (rd)
                    (space)
                    (let ((val (parse-value)))
                      (let ((new-rev-elements
                             (cons (cons (string->symbol str) val) rev-elements)))
                        (space)
                        (let ((c (pk)))
                          (cond ((eqv? c #\})
                                 (rd)
                                 (create-object
                                  (reverse new-rev-elements)))
                                ((eqv? c #\,)
                                 (rd)
                                 (space)
                                 (loop new-rev-elements))
                                (else
                                 (error "Invalid character in JSON object")))))))))))))

  (define (parse-array)
    (rd) ;; skip #\[
    (space)
    (if (eqv? (pk) #\])
        (begin (rd) '())
        (let ((x (parse-value)))
          (let loop ((rev-elements (list x)))
            (space)
            (let ((c (pk)))
              (cond ((eqv? c #\])
                     (rd)
                     (reverse rev-elements))
                    ((eqv? c #\,)
                     (rd)
                     (let ((y (parse-value)))
                       (loop (cons y rev-elements))))
                    (else
                     (error "Invalid character in JSON array"))))))))

  (define (parse-string)

    (define (parse-str pos)
      (let ((c (rd)))
        (cond ((eqv? c #\")
               (make-string pos))
              ((eqv? c #\\)
               (let ((x (rd)))
                 (if (eqv? x #\u)
                     (let loop ((n 0) (i 4))
                       (if (> i 0)
                           (let ((h (rd)))
                             (cond ((not (char? h))
                                    (error "parse-string" "EOF while reading string"))
                                   ((digit? h 16)
                                    =>
                                    (lambda (d)
                                      (loop (+ (* n 16) d) (- i 1))))
                                   (else
                                    (error "parse-string" "Invalid Unicode escape"))))
                           (accum (integer->char n) pos (parse-str (+ pos 1)))))
                     (let ((e (assv x json-string-escapes)))
                       (if e
                           (accum (cdr e) pos (parse-str (+ pos 1)))
                           (error "parse-string" "Unrecognized escape character"))))))
              ((char? c)
               (accum c pos (parse-str (+ pos 1))))
              (else
               (error "parse-string" "EOF while reading string")))))

    (rd) ;; skip #\"
    (parse-str 0))

  (define (parse-number)

    (define (sign-part)
      (let ((c (pk)))
        (if (eqv? c #\-)
            (begin (rd) (accum c 0 (after-sign-part 1)))
            (after-sign-part 0))))

    (define (after-sign-part pos)
      (let ((c (pk)))
        (if (eqv? c #\0)
            (begin (rd) (accum c pos (after-zero-part (+ pos 1))))
            (after-first-digit pos))))

    (define (after-zero-part pos)
      (let ((c (pk)))
        (if (eqv? c #\.)
            (begin (rd) (accum c pos (decimals-part (+ pos 1))))
            (if (or (eqv? c #\e) (eqv? c #\E))
                (begin (rd) (accum c pos (exponent-sign-part (+ pos 1))))
                (done pos)))))

    (define (after-first-digit pos)
      (if (not (digit? (pk) 10))
          (error "parse-number" "Non-digit following a sign")
          (integer-part pos)))

    (define (integer-part pos)
      (let ((c (pk)))
        (if (digit? c 10)
            (begin (rd) (accum c pos (integer-part (+ pos 1))))
            (if (eqv? c #\.)
                (begin (rd) (accum c pos (decimals-part (+ pos 1))))
                (exponent-part pos)))))

    (define (decimals-part pos)
      (let ((c (pk)))
        (if (digit? c 10)
            (begin (rd) (accum c pos (after-first-decimal-digit (+ pos 1))))
            (error "parse-number" "Non-digit following a decimal point"))))

    (define (after-first-decimal-digit pos)
      (let ((c (pk)))
        (if (digit? c 10)
            (begin (rd) (accum c pos (after-first-decimal-digit (+ pos 1))))
            (exponent-part pos))))

    (define (exponent-part pos)
      (let ((c (pk)))
        (if (or (eqv? c #\e) (eqv? c #\E))
            (begin (rd) (accum c pos (exponent-sign-part (+ pos 1))))
            (done pos))))

    (define (exponent-sign-part pos)
      (let ((c (pk)))
        (if (or (eqv? c #\-) (eqv? c #\+))
            (begin (rd) (accum c pos (exponent-after-sign-part (+ pos 1))))
            (exponent-after-sign-part pos))))

    (define (exponent-after-sign-part pos)
      (if (not (digit? (pk) 10))
          (error "parse-number" "Non-digit following an exponent mark")
          (exponent-integer-part pos)))

    (define (exponent-integer-part pos)
      (let ((c (pk)))
        (if (digit? c 10)
            (begin (rd) (accum c pos (exponent-integer-part (+ pos 1))))
            (done pos))))

    (define (done pos)
      (make-string pos))

    (let ((str (sign-part)))
      (string->number str)))

  (let ((value (parse-value)))
    (let loop ((next-char (read-char port)))
       (if (eof-object? next-char)
           value
           (if (member next-char '(#\space #\newline #\tab #\return))
               (loop (read-char port))
               (error "json-read" "Extra data"))))))
          

;;;
;;;; --
;;;; JSON writer
;;;

(define (json-write obj . port-option)
  (define port (if (null? port-option)
                   (current-output-port)
                   (if (null? (cdr port-option))
                       (car port-option)
                       (error "json-read" "Too many arguments"))))

  (define (wr-string s)
    (display #\" port)
    (let loop ((i 0) (j 0))
      (if (< j (string-length s))
          (let* ((c
                  (string-ref s j))
                 (n
                  (char->integer c))
                 (ctrl-char?
                  (or (<= n 31) (>= n 127)))
                 (x
                  (cond ((or (char=? c #\\)
                             (char=? c #\"))
                         c)
                        ((and ctrl-char?
                              (assv c reverse-json-string-escapes))
                         =>
                         cdr)
                        (else
                         #f)))
                 (j+1
                  (+ j 1)))
            (if (or x ctrl-char?)
                (begin
                  (display (substring s i j) port)
                  (display #\\ port)
                  (if x
                      (begin
                        (display x port)
                        (loop j+1 j+1))
                      (begin
                        (display #\u port)
                        (display (substring (number->string (+ n #x10000) 16)
                                            1
                                            5)
                                 port)
                        (loop j+1 j+1))))
                (loop i j+1)))
          (begin
            (display (substring s i j) port)
            (display #\" port)))))

  (define (wr-prop prop)
    (wr (symbol->string (car prop)))
    (display ":" port)
    (wr (cdr prop)))

  (define (wr-object obj)
    (wr-props (hash-table->alist obj)))

  (define (wr-props lst)
    (display "{" port)
    (if (pair? lst)
        (begin
          (wr-prop (car lst))
          (let loop ((lst (cdr lst)))
            (if (pair? lst)
                (begin
                  (display "," port)
                  (wr-prop (car lst))
                  (loop (cdr lst)))))))
    (display "}" port))

  (define (wr-array obj)
    (display "[" port)
    (let loop ((not-first #f) (l obj))
       (if (not (null? l))
           (begin
             (if not-first (display "," port))
             (wr (car l))
             (loop #t (cdr l)))))
    (display "]" port))

  (define (wr obj)

    (cond ((number? obj)
           (write (if (integer? obj) obj (inexact obj)) port))

          ((string? obj)
           (wr-string obj))

          ((boolean? obj)
           (display (if obj "true" "false") port))

          ((json-null? obj)
           (display "null" port))

          ((list? obj)
           (wr-array obj))

          ((hash-table? obj)
           (wr-object obj))

          (else
           (error "unwritable object" obj))))

  (wr obj))

(define json-string-escapes
  '((#\" . #\")
    (#\\ . #\\)
    (#\/ . #\/)
    (#\b . #\x08)
    (#\t . #\x09)
    (#\n . #\x0A)
    (#\v . #\x0B)
    (#\f . #\x0C)
    (#\r . #\x0D)))

(define reverse-json-string-escapes
  (map (lambda (x)
         (cons (cdr x) (car x)))
       json-string-escapes))

;;;
;;;; --
;;;; Procedures for reading/writing for strings/files
;;;

(define (json-read-string s)
  (define p (open-input-string s))
  (let ((result (json-read p)))
    (close-input-port p)
    result))

(define (json-read-file filepath)
  (define p (open-input-file filepath))
  (let ((result (json-read p)))
    (close-input-port p)
    result))

(define (json-write-string value . prettify-options)
  (define prettify (if (null? prettify-options)
                       #f
                       (car prettify-options)))
  (define space-char (if (< (length prettify-options) 2)
                         #\tab
                         (list-ref prettify-options 1)))
  (define space-count (if (< (length prettify-options) 3)
                          1
                          (list-ref prettify-options 2)))
  (define p (open-output-string))
  (json-write value p)
  (let ((result (get-output-string p)))
    (close-output-port p)
    (if prettify
        (json-prettify result space-char space-count)
        result)))

(define (json-write-file value filepath . prettify-options)
  (define prettify (if (null? prettify-options)
                       #f
                       (car prettify-options)))
  (define p (open-output-file filepath))
  (if prettify
      (display (apply json-write-string (cons value prettify-options)) p)
      (json-write value p))
  (close-output-port p))

;;;
;;;; --
;;;; Prettify procedure
;;;

(define (json-prettify str space-char space-count)
  (define (add-spaces l level)
    (let loop ((i 0) (result l))
      (if (< i (* level space-count))
          (loop (+ i 1) (cons space-char result))
          result)))

  (define (is-empty slist char-look)
    (let loop ((l slist))
      (if (null? slist)
          #f
          (case (car l)
            ((#\])
             (if (equal? char-look #\[)
                 (cdr l)
                 #f))
            ((#\})
             (if (equal? char-look #\{)
                 (cdr l)
                 #f))
            ((#\space #\newline #\tab #\return)
             (loop (cdr l)))
            (else #f)))))

  (let loop ((l (string->list str))
             (level 0)
             (slist '())
             (in-string #f))
    (cond
     ((null? l)
      (list->string (reverse (cons #\newline
                                   slist))))
     ((equal? (car l) #\")
      (loop (cdr l)
            level
            (cons (car l) slist)
            (if (and (not (null? slist)) (equal? (car slist) #\\))
                in-string
                (not in-string))))
     (in-string
      (loop (cdr l) level (cons (car l) slist) #t))
     (else
      (case (car l)
        ((#\[ #\{)
         (if (is-empty (cdr l) (car l))
             (loop (is-empty (cdr l) (car l))
                   level
                   (cons (if (equal? (car l)
                                     #\[)
                             #\]
                             #\})
                         (cons (car l)
                               slist))
                   #f)
             (loop (cdr l)
                   (+ level 1)
                   (add-spaces (cons #\newline
                                     (cons (car l)
                                           slist))
                               (+ level 1))
                   #f)))
        ((#\] #\})
         (loop (cdr l)
               (- level 1)
               (cons (car l)
                     (add-spaces (cons #\newline
                                       slist)
                                 (- level 1)))
               #f))
        ((#\,)
         (loop (cdr l)
               level
               (add-spaces (cons #\newline
                                 (cons (car l)
                                       slist))
                           level)
               #f))
        ((#\:)
         (loop (cdr l)
               level
               (cons #\space
                     (cons (car l)
                           slist))
               #f))
        ((#\space #\newline #\tab #\return)
         (loop (cdr l) level slist #f))
        (else
         (loop (cdr l)
               level
               (cons (car l) slist)
               #f)))))))
