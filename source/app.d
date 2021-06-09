import std.process;
import std.stdio : readln;
import std.string : strip;

import til.nodes;
import til.ranges;


class OutputRange : Range
{
    ProcessPipes pipes;
    std.process.Pid pid;
    CommandContext context;
    Range inputStream;
    string[] command;
    int returnCode = 0;
    bool running = true;
    Dict processHandler;

    this(string[] command, Dict processHandler, CommandContext context)
    {
        this.context = context;
        this.processHandler = processHandler;
        this.command = command;

        if (inputStream is null)
        {
            pipes = pipeProcess(command, Redirect.stdout | Redirect.stderr);
        }
        else
        {
            pipes = pipeProcess(command, Redirect.all);
        }
        this.pid = pipes.pid;
    }

    override bool empty()
    {
        if (!running) return true;

        if (pipes.stdout.eof && pipes.stderr.eof)
        {
            /*
            If both stdout and stderr are closed but the
            process is not terminated, then we ARE
            going to return "yes, it's empty",
            but must also block the current
            Til process until the system
            process is really
            terminated:
            */
            while (!pid.tryWait().terminated)
            {
                context.yield();
            }

            returnCode = pid.wait();
            running = false;
            processHandler["running"] = new BooleanAtom(false);
            processHandler["return_code"] = new IntegerAtom(returnCode);

            return false;
        }
        return false;
    }
    override ListItem front()
    {
        if (!running)
        {
            return new SimpleList([
                new IntegerAtom(0),
                new IntegerAtom(returnCode)
            ]);
        }

        string line = null;
        int source;

        while(line is null)
        {
            if (!pipes.stderr.eof)
            {
                line = pipes.stderr.readln();
                // XXX : dont'like to say "2". It would be
                // nice to get the fd number directly
                // from pipes.stderr/stdout.
                source = 2;
            }

            if (line is null && !pipes.stdout.eof)
            {
                line = pipes.stdout.readln();
                source = 1;
            }

            if (line is null)
            {
                if (pipes.stdout.eof && pipes.stderr.eof)
                {
                    source = -1;
                    line = "";
                    break;
                }
                context.yield();
            }
        }

        return new SimpleList([
            new IntegerAtom(source),
            new String(line.strip("\n"))
        ]);
    }
    override void popFront()
    {
    }
}

extern (C) CommandHandler[string] getCommands(Process escopo)
{
    CommandHandler[string] commands;

    commands[null] = (string path, CommandContext context)
    {
        string[] cmd = context.items!string;

        auto processHandler = new Dict();
        processHandler["command"] = new String(to!string(
            cmd.map!(x => to!string(x)).join(" ")
        ));
        processHandler["running"] = new BooleanAtom(true);

        context.stream = new OutputRange(cmd, processHandler, context);
        context.push(processHandler);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    return commands;
}
