import std.process : execute;

import til.nodes;


extern (C) CommandHandler[string] getCommands()
{
    CommandHandler[string] commands;

    commands[null] = (string path, CommandContext context)
    {
        string[] arguments = context.items!string;
        auto result = execute(arguments);

        context.push(new Dict([
            "status": new IntegerAtom(result.status),
            "output": new String(result.output),
        ]));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    return commands;
}
