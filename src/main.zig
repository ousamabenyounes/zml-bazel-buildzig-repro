const checks = @import("checks.zig");

pub fn main() !void {
    try checks.validateZmlFacade();
    checks.printSummary();
}
