#!/usr/bin/env python3
"""
Simple SPA server for Flutter web app.
Serves index.html for all routes that don't match static files.
"""
import http.server
import socketserver
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
DIRECTORY = "/home/ubuntu/note/book/build/web"

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # Check if the requested path exists as a file
        path = self.translate_path(self.path)

        if os.path.exists(path) and os.path.isfile(path):
            # Serve the file normally
            return super().do_GET()

        # For SPA: serve index.html for all other routes
        self.path = '/index.html'
        return super().do_GET()

    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {args[0]}")

if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), SPAHandler) as httpd:
        print(f"Serving Flutter app at http://0.0.0.0:{PORT}")
        print(f"Directory: {DIRECTORY}")
        print("Press Ctrl+C to stop")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")
