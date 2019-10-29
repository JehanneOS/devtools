(package
  (maintainers "Jason K MacDuffie <taknamay@gmail.com>")
  (authors "Marc Feeley")
  (version "0.9.5")
  (license Expat (MIT))
  (library
    (name
      (macduffie json))
    (path "json.sld")
    (depends
      (scheme base)
      (scheme char)
      (scheme file)
      (scheme inexact)
      (scheme read)
      (scheme write)
      (srfi 69)))
  (manual "json.xhtml")
  (description "JSON reader and writer"))
