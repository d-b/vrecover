const std = @import("std");
const win = @import("std").os.windows;
const expect = @import("std").testing.expect;

const WINAPI = @import("std").os.windows.WINAPI;
const win32 = struct {
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").globalization;
    usingnamespace @import("win32").system.diagnostics.tool_help;
    usingnamespace @import("win32").system.library_loader;
    usingnamespace @import("win32").system.threading;
    usingnamespace @import("win32").system.windows_programming;
    usingnamespace @import("win32").ui.shell;
    usingnamespace @import("win32").ui.windows_and_messaging;
};

const target_process = "vrcompositer.exe";

pub fn main() !void {
    while (true) {
        const name = std.unicode.utf8ToUtf16LeStringLiteral(target_process);
        const process = openProcessByName(name) catch |err| switch (err) {
            error.ProcessNotFound => {
                std.debug.print("Process {s} not found\n", .{target_process});
                std.time.sleep(std.time.ns_per_s * 1);
                continue;
            },
            else => return err,
        };

        _ = win32.WaitForSingleObject(process, win32.INFINITE);
    }
}

fn openProcessByName(processName: [*:0]const u16) !win32.HANDLE {
    const pid = try findProcessByName(processName);
    const process = win32.OpenProcess(win32.PROCESS_ALL_ACCESS, win.FALSE, pid) orelse return error.AccessDenied;
    return process;
}

fn findProcessByName(processName: [*:0]const u16) !u32 {
    const snapshot = win32.CreateToolhelp32Snapshot(win32.TH32CS_SNAPPROCESS, 0);
    if (snapshot == win32.INVALID_HANDLE_VALUE) return error.InvalidSnapshot;
    defer _ = win32.CloseHandle(snapshot);

    var entry: win32.PROCESSENTRY32W = undefined;
    entry.dwSize = @sizeOf(win32.PROCESSENTRY32W);

    if (win32.Process32FirstW(snapshot, &entry) == win.FALSE) return error.ProcessNotFound;

    while (true) {
        const len = entry.szExeFile.len - 1;
        const name = entry.szExeFile[0..len :0];

        if (win32.lstrcmpiW(name, processName) == 0) return entry.th32ProcessID;
        if (win32.Process32NextW(snapshot, &entry) == win.FALSE) return error.ProcessNotFound;
    }
}

test "findProcessByName finds the current process" {
    var process: [win32.MAX_PATH:0]u16 = undefined;
    try expect(win32.GetModuleFileNameW(null, &process, process.len) != 0);
    const filename = win32.PathFindFileNameW(&process).?;
    try expect(try findProcessByName(filename) == win32.GetCurrentProcessId());
}

test "openProcessByName opens the current process" {
    var process: [win32.MAX_PATH:0]u16 = undefined;
    try expect(win32.GetModuleFileNameW(null, &process, process.len) != 0);
    const filename = win32.PathFindFileNameW(&process).?;
    const handle = try openProcessByName(filename);
    try expect(win32.GetProcessId(handle) == win32.GetCurrentProcessId());
    try expect(win32.CloseHandle(handle) == win.TRUE);
}
