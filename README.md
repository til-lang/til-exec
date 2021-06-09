# til-exec

Run system programs using [Til](https://til-lang.github.io/til/).

## Commands

### exec PARAMETERS

(That is: the module name itself.)

```tcl
exec ls /etc
    | case (2 >line) {
        print "error: $line"
    } case (1 >line) {
        print "output: $line"
    } case (0 >status) {
        print "exit status: $status"
    }
```
