"""Local streaming fixture. Uses the existing CC0 test MP3; never ships music."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import time
AUDIO = Path("build/crt-power-original-preview.mp3").read_bytes()
class Handler(BaseHTTPRequestHandler):
    protocol_version="HTTP/1.1"
    def log_message(self,*args): print(args,flush=True)
    def do_GET(self):
        if self.path=="/redirect":
            self.send_response(302); self.send_header("Location","/stream"); self.send_header("Content-Length","0"); self.end_headers(); return
        self.send_response(200)
        self.send_header("Content-Type", "audio/aac" if self.path=="/bad" else "audio/mpeg")
        if self.path=="/icy": self.send_header("icy-metaint","4096")
        self.send_header("Connection","close"); self.end_headers()
        if self.path in ["/bad","/drop"]: self.close_connection=True; return
        pos=0; interval=4096
        try:
            for n in range(2000):
                data=bytes(AUDIO[(pos+i)%len(AUDIO)] for i in range(521)); pos+=len(data)
                if self.path=="/icy":
                    out=bytearray()
                    for value in data:
                        out.append(value); interval-=1
                        if interval==0: out.extend(b"\x01"+b"metadata".ljust(16,b" ")); interval=4096
                    data=out
                self.wfile.write(data); self.wfile.flush(); time.sleep(.005)
        except (BrokenPipeError,ConnectionResetError,ConnectionAbortedError): pass
ThreadingHTTPServer(("127.0.0.1",18764),Handler).serve_forever()
