# til-exec

Run system programs using [Til](https://til-lang.github.io/til/).

## Commands

### exec PARAMETERS

(That is: the module name itself.)

```tcl
proc on.error (e) {
    if (<$e class> == "exec") {
        set process <$e object>
        print "Process returned " <$process return_code>

        extract $process error | foreach line {
            print "error: $line"
        }
    } else {
        return $e
    }
}

exec ls /etc | foreach line {
    print "output: $line"
}
```
