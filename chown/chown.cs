#:property PublishAot=true
#:property InvariantGlobalization=true
#:property StripSymbols=true
#:property OptimizationPreference=Size
#:property IlcOptimizationPreference=Size
#:property StackTraceSupport=false
#:property UseSystemResourceKeys=true
#:property IlcTrimMetadata=true
#:property AllowUnsafeBlocks=true
#:property AssemblyName=chown

using System.Runtime.InteropServices;

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: chown [-R] uid:gid path [path...]");
    return 1;
}

var recursive = false;
var argIndex = 0;

if (args[argIndex] == "-R")
{
    recursive = true;
    argIndex++;
}

if (argIndex >= args.Length - 1)
{
    Console.Error.WriteLine("Usage: chown [-R] uid:gid path [path...]");
    return 1;
}

var ownerSpec = args[argIndex++];
var separatorIndex = ownerSpec.IndexOf(':');
if (separatorIndex <= 0 ||
    !uint.TryParse(ownerSpec.AsSpan(0, separatorIndex), out var uid) ||
    !uint.TryParse(ownerSpec.AsSpan(separatorIndex + 1), out var gid))
{
    Console.Error.WriteLine($"chown: invalid owner '{ownerSpec}' (expected uid:gid)");
    return 1;
}

var failed = false;

for (var i = argIndex; i < args.Length; i++)
    failed |= recursive
        ? ChownRecursive(args[i], uid, gid)
        : Chown(args[i], uid, gid);

return failed ? 1 : 0;

static bool Chown(string path, uint uid, uint gid)
{
    if (NativeMethods.lchown(path, uid, gid) == 0)
        return false;

    Console.Error.WriteLine($"chown: '{path}': errno {Marshal.GetLastPInvokeError()}");
    return true;
}

static bool ChownRecursive(string path, uint uid, uint gid)
{
    var failed = Chown(path, uid, gid);

    if (new FileInfo(path).LinkTarget is not null || !Directory.Exists(path))
        return failed;

    try
    {
        foreach (var entry in Directory.EnumerateFileSystemEntries(path))
            failed |= ChownRecursive(entry, uid, gid);
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"chown: '{path}': {ex.Message}");
        failed = true;
    }

    return failed;
}

internal static partial class NativeMethods
{
    [LibraryImport("libc", SetLastError = true, StringMarshalling = StringMarshalling.Utf8)]
    internal static partial int lchown(string path, uint uid, uint gid);
}
