import time

def start_timer():
    return time.time()

def stop_timer(start_time):
    return time.time() - start_time
