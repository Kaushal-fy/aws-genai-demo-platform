import time
import uuid
import json
from contextvars import ContextVar

trace_id_var = ContextVar("trace_id", default=None)


def start_trace():
    trace_id = str(uuid.uuid4())
    trace_id_var.set(trace_id)
    return trace_id


def get_trace_id():
    return trace_id_var.get()


def log(event: str, data: dict = None):

    log_entry = {
        "trace_id": get_trace_id(),
        "event": event,
        "timestamp": time.time(),
        "data": data or {}
    }

    print(json.dumps(log_entry))


def time_it(fn):

    def wrapper(*args, **kwargs):

        start = time.time()
        result = fn(*args, **kwargs)
        end = time.time()

        log("latency", {
            "function": fn.__name__,
            "duration_ms": round((end - start) * 1000, 2)
        })

        return result

    return wrapper
