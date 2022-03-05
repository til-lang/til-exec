import std.array;
import std.process;
import std.stdio : readln;
import std.string;

import til.nodes;


CommandsMap systemProcessCommands;


class SystemProcess : ListItem
{
    ProcessPipes pipes;
    std.process.Pid pid;
    ListItem inputStream;
    string[] command;
    int returnCode = 0;
    bool _isRunning;

    auto type = ObjectType.SystemProcess;
    auto typeName = "system_process";

    bool isRunning()
    {
        if (_isRunning)
        {
            _isRunning = !this.pid.tryWait().terminated;
        }
        return _isRunning;
    }

    this(string[] command, ListItem inputStream)
    {
        this.command = command;
        this.inputStream = inputStream;

        if (inputStream is null)
        {
            pipes = pipeProcess(command, Redirect.stdout | Redirect.stderr);
        }
        else
        {
            pipes = pipeProcess(command, Redirect.all);
        }

        this.pid = pipes.pid;
        this.commands = systemProcessCommands;
    }

    override string toString()
    {
        return this.command.join(" ");
    }

    override Context next(Context context)
    {
        // For the output:
        string line = null;

        while (true)
        {
            // Send from inputStream, first:
            if (inputStream !is null)
            {
                auto inputContext = this.inputStream.next(context);
                if (inputContext.exitCode == ExitCode.Break)
                {
                    this.inputStream = null;
                    pipes.stdin.close();
                    continue;
                }
                else if (inputContext.exitCode != ExitCode.Continue)
                {
                    auto msg = "Error while reading from " ~ this.toString();
                    return context.error(msg, returnCode, "exec");
                }

                foreach (item; inputContext.items)
                {
                    string s = item.toString();
                    pipes.stdin.writeln(s);
                    pipes.stdin.flush();
                }
                continue;
            }

            if (pipes.stdout.eof)
            {
                while (isRunning)
                {
                    context.yield();
                }

                wait();
                _isRunning = false;

                if (returnCode != 0)
                {
                    auto msg = "Error while executing " ~ this.toString();
                    return context.error(msg, returnCode, "exec", this);
                }
                else
                {
                    context.exitCode = ExitCode.Break;
                    return context;
                }
            }

            line = pipes.stdout.readln();

            if (line is null)
            {
                context.yield();
                continue;
            }
            else
            {
                break;
            }
        }

        context.push(line.stripRight("\n"));
        context.exitCode = ExitCode.Continue;
        return context;
    }
    void wait()
    {
        returnCode = pid.wait();
    }
}

class SystemProcessError : ListItem
{
    SystemProcess parent;
    ProcessPipes pipes;
    this(SystemProcess parent)
    {
        this.parent = parent;
        this.pipes = parent.pipes;
    }

    override string toString()
    {
        return "error stream for " ~ this.parent.toString();
    }

    override Context next(Context context)
    {
        // For the output:
        string line = null;

        while (true)
        {
            if (!pipes.stderr.eof)
            {
                line = pipes.stderr.readln();
                if (line is null)
                {
                    context.yield();
                    continue;
                }
                else
                {
                    break;
                }
            }
            else 
            {
                context.exitCode = ExitCode.Break;
                return context;
            }
        }

        context.push(line.stripRight("\n"));
        context.exitCode = ExitCode.Continue;
        return context;
    }
}


extern (C) CommandsMap getCommands(Escopo escopo)
{
    systemProcessCommands[null] = new Command((string path, Context context)
    {
        string[] command;
        ListItem inputStream;

        if (context.inputSize == 1)
        {
            command = context.pop(context.size - 1).map!(x => to!string(x)).array;
            inputStream = context.pop();
        }
        else if (context.inputSize > 1)
        {
            auto msg = path ~ ": cannot handle multiple inputs";
            return context.error(msg, ErrorCode.InvalidInput, "exec");
        }
        else
        {
            command = context.items.map!(x => to!string(x)).array;
        }

        try
        {
            context.push(new SystemProcess(command, inputStream));
        }
        catch (ProcessException ex)
        {
            return context.error(ex.msg, ErrorCode.Unknown, "exec");
        }
        return context;
    });
    systemProcessCommands["extract"] = new Command((string path, Context context)
    {

        SystemProcess target = context.pop!SystemProcess();

        if (context.size == 0) return context;
        string argument = context.pop!string();

        switch (argument)
        {
            case "is_running":
                context.push(target.isRunning);
                break;
            case "command":
                foreach (item; target.command)
                {
                    context.push(item);
                }
                break;
            case "pid":
                context.push(target.pid.processID());
                break;
            case "return_code":
                if (target.isRunning)
                {
                    auto msg = "Process is still running";
                    return context.error(msg, ErrorCode.RuntimeError, "");
                }
                else
                {
                    context.push(target.returnCode);
                }
                break;
            case "error":
                context.push(new SystemProcessError(target));
                break;
            default:
                break;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    systemProcessCommands["wait"] = new Command((string path, Context context)
    {
        auto p = context.pop!SystemProcess();
        p.wait();
        return context.push(p.returnCode);
    });

    return systemProcessCommands;
}
