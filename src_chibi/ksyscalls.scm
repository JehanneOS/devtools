(import (macduffie json))


(define (ureg-arg x)
  (case x
        ((0)    "di")
        ((1)    "si")
        ((2)    "dx")
        ((3)    "r10")
        ((4)    "r8")
        ((5)    "r9"))
        ((else) ""))

(define (sysret x)
  (case x
    (("int")       "i")
    (("int32_t")   "i")
    (("long")      "vl")
    (("int64_t")   "vl")
    (("uintptr_t") "p")
    (("void")      "p")
    (("void*")     "v")
    (("char*")     "v")
    (("char**")    "v")
    (("uint8_t*")  "v")
    (("int32_t*")  "v")
    (("uint64_t*") "v")
    (("int64_t*")  "v")
    ((else)        (string-append "[?? " x "]"))))

(define (format-arg i str)
  (let ((stri (number->string i))
        (sa string-append))
    (case str
      ((or "int" "int32_t")
       (sa "\tjehanne_fmtprint(fmt, \" %%d\", a" stri ");\n"))
      ((or "unsigned int" "uint32_t")  ; unsigned int is reserved for flags
       (sa "\tjehanne_fmtprint(fmt, \" %#ux\", a" stri ");\n"))
      ((or "long" "int64_t")
       (sa "\tjehanne_fmtprint(fmt, \" %lld\", a" stri ");\n"))
      ((or "unsigned long" "uint64_t")
       (sa "\tjehanne_fmtprint(fmt, \" %#lud\", a" stri ");\n", i))
      ((or "void*" "uint8_t*" "const void*" "const uint8_t*")
       (sa "\tjehanne_fmtprint(fmt, \" %#p\", a" stri");\n"))
      ((or "int32_t*" "int*" "const int32_t*" "const int*")
       (sa "\tjehanne_fmtprint(fmt, \" %#p(%d)\", a" stri ", a" stri ");\n"))
      ((or "const char*" "char*")
       (sa "\tfmtuserstring(fmt, a" stri ");\n"))
      ((or "const char**" "char**")
       (sa "\tfmtuserstringlist(fmt, a" stri ");\n"))
      ((else)
       (sa "[?? " str "]")))))

(define (format-ret t)
  (let ((sysret (sysret t))
        (sa string-append))
    (case t
      ((or "int" "int32_t")
       (sa "\tjehanne_fmtprint(fmt, \" %d\", ret->" sysret ");\n"))
      ((or "unsigned int" "uint32_t")  ; unsigned int is reserved for flags
       (sa "\tjehanne_fmtprint(fmt, \" %#ux\", ret->" sysret ");\n"))
      ((or "long" "int64_t")
       (sa "\tjehanne_fmtprint(fmt, \" %lld\", ret->" sysret ");\n"))
      ((or "unsigned long" "uint64_t" "void")
       (sa "\tjehanne_fmtprint(fmt, \" %#llud\", ret->" sysret ");\n"))
      ((or "void*" "uintptr_t" "const void*" "const uintptr_t")
       (sa "\tjehanne_fmtprint(fmt, \" %#p\", ret->" sysret ");\n"))
      ((or "int32_t*" "int*" "const int32_t*" "const int*")
       (sa "\tjehanne_fmtprint(fmt, \" %#p(%%d)\", ret->" sysret
           ", *ret->" sysret ");\n"))
      ((else)
       (sa "[?? " t "]")))))


; Scheme  JSON
; Hash table (srfi 69)  Object
; List  Array
; String  String
; Number  Number
; #t  true
; #f  false
; json-null record type   null
(define (generate-kernel-code syscalls)
  )

(define (main args)
  (if (= 1 (length args))
      (call-with-input-file
        (cadr args)
        (lambda (x)
          (generate-kernel-code (let ((data (json-read x)))
                                  (if (json-null? data)
                                      (error "No data in json file")
                                      data)))))
      (error "Usage: ksyscalls path/to/sysconf.json\n")))

(main (command-line))
