# til-exec

Run system programs using [Til](https://til-lang.github.io/til/).

## Commands

### exec PARAMETERS

(That is: the module name itself.)

```tcl
set result [exec ls /etc]
io.out "status: " <$result status>
io.out "output: " <$result output>
```
