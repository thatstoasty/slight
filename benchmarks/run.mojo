from std import pathlib, time, benchmark
from std.benchmark import Bench, BenchConfig, Bencher, BenchId, BenchMetric, ThroughputMeasure
from std.python import Python, PythonObject
from std.sys import argv
from std.pathlib import Path

from slight import Connection
from slight.vtab.csvtab import load_module

from functions.bench_csvtab import CSVTabBenchContext, bench_csvtab_full_scan, bench_csvtab_count, bench_csvtab_filter, bench_csvtab_create_and_drop
from functions.bench_execute import bench_connect_overhead, bench_execute_single_insert, bench_execute_batch
from functions.bench_statement import bench_prepare, bench_bind_positional, bench_bind_named, bench_reset_and_rebind
from functions.bench_query import bench_query_raw_rows, bench_query_mapped, bench_query_typed_reflection, bench_one_row
from functions.bench_transaction import bench_transaction_commit, bench_transaction_rollback, bench_savepoint_nested
from functions.bench_functions import bench_udf_registration, bench_scalar_udf, bench_aggregate_udf, bench_window_udf

comptime BenchResults = Dict[String, Float64]

def run_benchmarks(mut m: Bench) raises:
    var args = argv()
    var print_relative = False
    var overwrite = False

    for i in range(len(args)):
        if args[i] == "--print-relative":
            print_relative = True
        if args[i] == "--overwrite":
            overwrite = True

    var report_str: String
    if print_relative or overwrite:
        report_str = capture_report(m)
        print(report_str)
    else:
        m.dump_report()
        return

    var new_results = parse_report(report_str)

    if print_relative:
        var old_content: String = ""
        try:
            with open("bench_result.txt", "r") as f:
                old_content = f.read()
        except:
            print("Could not read bench_result.txt for comparison")
        var old_results = parse_report(old_content)
        print_relative_performance(old_results^, new_results^)

    if overwrite:
        write_report(report_str)


def capture_report(mut m: Bench) raises -> String:
    var os = Python.import_module("os")
    var sys_py = Python.import_module("sys")
    var io = Python.import_module("io")

    # Create pipe
    var r_w = os.pipe()  # Returns (r, w) tuple
    var r = r_w[0]
    var w = r_w[1]

    var stdout_fd = sys_py.stdout.fileno()
    var saved_stdout = os.dup(stdout_fd)

    # Redirect stdout to pipe
    _ = os.dup2(w, stdout_fd)

    m.dump_report()

    # Flush and restore
    _ = sys_py.stdout.flush()
    _ = os.dup2(saved_stdout, stdout_fd)
    _ = os.close(w)

    # Read from pipe
    var file_obj = os.fdopen(r)
    var content = file_obj.read()

    return String(content)


def parse_report(report: String) raises -> BenchResults:
    var lines = report.split("\n")
    var results = BenchResults()

    # Find header index
    var header_idx = -1
    var col_idx = -1
    for i in range(len(lines)):
        if "mean (ms)" in lines[i]:
            header_idx = i
            var parts = lines[i].split("|")
            for j in range(len(parts)):
                if "mean (ms)" in parts[j]:
                    col_idx = j
            break

    if header_idx == -1 or col_idx == -1:
        return results^

    for i in range(header_idx + 1, len(lines)):
        var line = lines[i]
        if not line or line.strip().startswith("-"):
            continue
        var parts = line.split("|")
        if len(parts) > col_idx:
            var name = parts[1].strip()
            var val_str = parts[col_idx].strip()
            try:
                # Try direct Float64 parsing from string
                var val_flt = Float64(val_str)
                results[String(name)] = val_flt
            except:
                pass

    return results^


def print_relative_performance(
    var old_results: BenchResults,
    var new_results: BenchResults,
) raises:
    print("")
    print("Relative Performance (mean ms vs bench_result.txt)")
    print(
        "---------------------------------------------------------------------------------------------------------"
    )
    print(
        "| Benchmark Name                                | Old (ms)   | New"
        " (ms)   | Diff       | Speedup     |"
    )
    print(
        "|-----------------------------------------------|------------|------------|------------|-------------|"
    )

    for item in new_results.items():
        var name = item.key
        var new_val = item.value

        var name_pad = name
        while name_pad.byte_length() < 45:
            name_pad = name_pad + " "

        if name in old_results:
            var old_val = old_results[name]
            # Lower mean execution time is better, so a positive diff_pct
            # (new is slower than old) is a regression, not an improvement.
            var diff_pct = (new_val - old_val) / old_val * 100.0
            var speedup = old_val / new_val

            var sign = "+" if diff_pct >= 0 else ""
            var diff_str = String(sign + String(diff_pct)[byte=0:5] + "%")
            var speedup_str = String(String(speedup)[byte=0:4] + "x")
            var old_str = String(String(old_val)[byte=0:6])
            var new_str = String(String(new_val)[byte=0:6])

            # Pad output manually (inefficient but works without formatting lib)
            var pad_len = 10
            while old_str.byte_length() < pad_len:
                old_str = old_str + " "
            while new_str.byte_length() < pad_len:
                new_str = new_str + " "
            while diff_str.byte_length() < pad_len:
                diff_str = diff_str + " "
            while speedup_str.byte_length() < 11:
                speedup_str = speedup_str + " "

            # Color the diff/speedup columns. Apply after padding so the visual
            # column widths stay aligned (ANSI escapes are zero-width).
            # Threshold: ±1% to avoid coloring obvious noise. Since lower ms
            # is better, a slowdown (diff_pct > 1%) is colored red and a
            # speedup (diff_pct < -1%) is colored green -- the opposite of a
            # throughput metric where higher is better.
            comptime ANSI_GREEN = "\x1b[32m"
            comptime ANSI_RED = "\x1b[31m"
            comptime ANSI_RESET = "\x1b[0m"
            if diff_pct < -1.0:
                diff_str = ANSI_GREEN + diff_str + ANSI_RESET
                speedup_str = ANSI_GREEN + speedup_str + ANSI_RESET
            elif diff_pct > 1.0:
                diff_str = ANSI_RED + diff_str + ANSI_RESET
                speedup_str = ANSI_RED + speedup_str + ANSI_RESET

            print(
                "| "
                + name_pad
                + " | "
                + old_str
                + " | "
                + new_str
                + " | "
                + diff_str
                + " | "
                + speedup_str
                + " |"
            )
        else:
            print(
                "| "
                + name_pad
                + " | N/A        | "
                + String(new_val)[byte=0:6]
                + "     | N/A        | N/A         |"
            )

    print(
        "---------------------------------------------------------------------------------------------------------"
    )
    print("")


def write_report(report: String) raises:
    var header = String("Run on unknown system")
    try:
        var platform = Python.import_module("platform")
        var system = String(platform.system())

        var cpu_info = String("")
        if system == "Darwin":
            var subprocess = Python.import_module("subprocess")
            # Try to get MacOS CPU brand string
            try:
                var cmd = Python.evaluate(
                    "['sysctl', '-n', 'machdep.cpu.brand_string']"
                )
                var res = subprocess.check_output(cmd).decode("utf-8").strip()
                cpu_info = String(res)

                var cmd_cores = Python.evaluate(
                    "['sysctl', '-n', 'hw.physicalcpu']"
                )
                var cores = (
                    subprocess.check_output(cmd_cores).decode("utf-8").strip()
                )

                var cmd_mem = Python.evaluate("['sysctl', '-n', 'hw.memsize']")
                var mem_bytes = (
                    subprocess.check_output(cmd_mem).decode("utf-8").strip()
                )
                # Use Python to format bytes to GB
                var mem_gb_py = Python.evaluate(
                    "'{:.2f}'.format(" + String(mem_bytes) + "/(1024**3))"
                )
                var mem_gb = String(mem_gb_py)

                cpu_info = (
                    cpu_info
                    + "\nCores: "
                    + String(cores)
                    + "\nMemory: "
                    + mem_gb
                    + " GB"
                )
            except:
                pass

        if cpu_info.byte_length() == 0:
            cpu_info = (
                String(platform.machine()) + " " + String(platform.processor())
            )

        header = (
            "Run on "
            + String(system)
            + " "
            + String(platform.release())
            + "\nCPU: "
            + cpu_info
        )
    except:
        pass

    var content = header + "\n\n" + report
    with open("bench_result.txt", "w") as f:
        f.write(content)
    print("Updated bench_result.txt")


def get_gbs_measure(input: String) raises -> ThroughputMeasure:
    return ThroughputMeasure(BenchMetric.bytes, input.byte_length())


def _build_insert_function_bench_data_sql[count: Int]() -> String:
    var sql = ""
    comptime for i in range(count):
        sql.write(t"INSERT INTO t (value) VALUES ({i});")
    return sql^


def _build_insert_iteration_bench_data_sql[count: Int]() -> String:
    var sql = ""
    comptime for i in range(count):
        sql.write(t"INSERT INTO t (id, name, value) VALUES ({i}, 'row', {i});")
    return sql^


def run[func: def (mut Bencher, String) raises capturing, name: String](mut m: Bench, data: String) raises:
    m.bench_with_input[String, func](BenchId(name), data, [get_gbs_measure(data)])


def run[func: def (mut Bencher) raises capturing, name: String](mut m: Bench) raises:
    m.bench_function[func](BenchId(name))


def _bytes_measure(n_bytes: Int) raises -> ThroughputMeasure:
    return ThroughputMeasure(BenchMetric.bytes, n_bytes)


def run[
    func: def (mut Bencher, String) raises capturing,
    name: String,
](mut m: Bench, csv_path: String, file_bytes: Int) raises:
    m.bench_with_input[String, func](BenchId(name), csv_path, [_bytes_measure(file_bytes)])


comptime CSVTabBenchFn[origin: ImmOrigin] = def (mut Bencher, CSVTabBenchContext[origin]) raises capturing thin

def run_with_context[
    origin: ImmOrigin, //,
    func: CSVTabBenchFn[origin],
    name: String,
](mut m: Bench, ctx: CSVTabBenchContext[origin]) raises:
    m.bench_with_input[T=CSVTabBenchContext[origin], bench_fn=func](BenchId(name), ctx, [_bytes_measure(ctx.file_bytes)])


comptime ExecuteBenchFn = def (mut Bencher, Connection) raises capturing

def run[
    func: def (mut Bencher, Connection) raises capturing,
    name: String,
](mut m: Bench, conn: Connection) raises:
    m.bench_with_input[T=Connection, bench_fn=func](BenchId(name), conn)


def main() raises:
    var config = BenchConfig()
    config.verbose_timing = True
    config.flush_denormals = True
    config.show_progress = True
    var bench = Bench(config^)

    var csv_path = String(pathlib._dir_of_current_file()) + "/data/bench.csv"
    var file_bytes: Int
    with open(csv_path, "r") as f:
        file_bytes = f.read().byte_length()
    
    with Connection.open_in_memory() as conn:
        load_module(conn)
        conn.execute_batch(
            t"CREATE VIRTUAL TABLE t USING csv(filename='{csv_path}', header=yes)"
        )

        var csv_tab_context = CSVTabBenchContext(csv_path, file_bytes, Pointer(to=conn))
        run_with_context[bench_csvtab_full_scan[origin_of(conn)], "csvtab_full_scan"](bench, csv_tab_context)
        run_with_context[bench_csvtab_count[origin_of(conn)], "csvtab_count"](bench, csv_tab_context)
        run_with_context[bench_csvtab_filter[origin_of(conn)], "csvtab_filter"](bench, csv_tab_context)
        run_with_context[bench_csvtab_create_and_drop[origin_of(conn)], "csvtab_connect"](bench, csv_tab_context)

    # execute / execute_batch
    with Connection.open_in_memory() as conn:
        conn.execute_batch("CREATE TABLE t (id INTEGER, name TEXT, value REAL)")
        run[bench_connect_overhead, "connect_overhead"](bench)
        run[bench_execute_single_insert, "execute_single_insert"](bench, conn)
        run[bench_execute_batch, "execute_batch"](bench, conn)

    # prepare / bind / reset
    with Connection.open_in_memory() as conn:
        conn.execute_batch("CREATE TABLE t (id INTEGER, name TEXT, value REAL)")
        run[bench_prepare, "statement_prepare"](bench, conn)
        run[bench_bind_positional, "statement_bind_positional"](bench, conn)
        run[bench_bind_named, "statement_bind_named"](bench, conn)
        run[bench_reset_and_rebind, "statement_reset_and_rebind"](bench, conn)

    # row iteration / mapping
    with Connection.open_in_memory() as conn:
        conn.execute_batch("CREATE TABLE t (id INTEGER, name TEXT, value REAL)")
        comptime sql = _build_insert_iteration_bench_data_sql[200]()
        conn.execute_batch(sql)
        run[bench_query_raw_rows, "query_raw_rows"](bench, conn)
        run[bench_query_mapped, "query_mapped"](bench, conn)
        run[bench_query_typed_reflection, "query_typed_reflection"](bench, conn)
        run[bench_one_row, "query_one_row"](bench, conn)

    # transactions / savepoints
    with Connection.open_in_memory() as conn:
        conn.execute_batch("CREATE TABLE t (id INTEGER)")
        run[bench_transaction_commit, "transaction_commit"](bench, conn)
        run[bench_transaction_rollback, "transaction_rollback"](bench, conn)
        run[bench_savepoint_nested, "savepoint_nested"](bench, conn)

    # scalar / aggregate / window functions
    with Connection.open_in_memory() as conn:
        comptime sql = _build_insert_function_bench_data_sql[200]()
        conn.execute_batch("CREATE TABLE t (value INTEGER)")
        conn.execute_batch(sql)
        run[bench_udf_registration, "udf_registration"](bench)
        run[bench_scalar_udf, "scalar_udf"](bench, conn)
        run[bench_aggregate_udf, "aggregate_udf"](bench, conn)
        run[bench_window_udf, "window_udf"](bench, conn)

    run_benchmarks(bench)
