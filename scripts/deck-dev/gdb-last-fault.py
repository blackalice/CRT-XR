import gdb
state = {"last": "", "count": 0}
def report():
    print("=== FAULTS SEEN: %d ; LAST FAULT BACKTRACE ===" % state["count"])
    print(state["last"])
def on_stop(event):
    if isinstance(event, gdb.SignalEvent) and event.stop_signal in ("SIGSEGV", "SIGBUS", "SIGILL", "SIGABRT", "SIGTRAP"):
        state["count"] += 1
        try:
            state["last"] = event.stop_signal + " in " + gdb.selected_thread().name + "\n" + gdb.execute("bt 22", to_string=True) + gdb.execute("info registers rip", to_string=True) + gdb.execute("x/6i $pc-6", to_string=True)
        except Exception as e:
            state["last"] = "bt failed: %s" % e
        if event.stop_signal in ("SIGSEGV",):
            gdb.post_event(lambda: gdb.execute("continue"))
        else:
            report()
def on_exit(event):
    report()
gdb.events.stop.connect(on_stop)
gdb.events.exited.connect(on_exit)
