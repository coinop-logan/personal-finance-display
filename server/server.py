#!/usr/bin/env python3
"""
Finance Display Server
A simple HTTP server that serves static files and provides a JSON API for data entry.
No external dependencies - uses only Python standard library.
"""

import http.server
import json
import os
from pathlib import Path
from urllib.parse import urlparse

PORT = int(os.environ.get('PORT', 3000))
DATA_FILE = Path(__file__).parent / 'data.json'
DIST_DIR = Path(__file__).parent.parent / 'dist'


def load_data():
    """Load entries from JSON file."""
    if DATA_FILE.exists():
        try:
            with open(DATA_FILE, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return []
    return []


def save_data(entries):
    """Save entries to JSON file."""
    with open(DATA_FILE, 'w') as f:
        json.dump(entries, f, indent=2)


class FinanceHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIST_DIR), **kwargs)

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == '/api/data':
            self.send_json_response(load_data())
        elif parsed.path.startswith('/api/'):
            self.send_error(404, 'API endpoint not found')
        else:
            # Serve static files, fall back to index.html for SPA routing
            file_path = DIST_DIR / parsed.path.lstrip('/')
            if file_path.is_file():
                super().do_GET()
            else:
                # SPA fallback - serve index.html for any non-file path
                self.path = '/index.html'
                super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path == '/api/entry':
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(content_length)
                entry = json.loads(body.decode('utf-8'))

                # Validate entry
                if not entry.get('date') or entry.get('amount') is None:
                    self.send_error(400, 'Missing date or amount')
                    return

                # Add to data
                entries = load_data()
                entries.append({
                    'date': entry['date'],
                    'amount': float(entry['amount']),
                    'label': entry.get('label', '')
                })

                # Sort by date
                entries.sort(key=lambda x: x['date'])

                save_data(entries)

                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(b'{"ok": true}')

            except (json.JSONDecodeError, ValueError) as e:
                self.send_error(400, f'Invalid JSON: {e}')
        else:
            self.send_error(404, 'Not found')

    def send_json_response(self, data):
        """Send a JSON response."""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def log_message(self, format, *args):
        """Quieter logging - only log errors and API calls."""
        if '/api/' in args[0] or '404' in str(args):
            super().log_message(format, *args)


def main():
    server = http.server.HTTPServer(('0.0.0.0', PORT), FinanceHandler)
    print(f'Finance Display Server running at http://localhost:{PORT}')
    print(f'Data entry: http://localhost:{PORT}/entry')
    print(f'Graph view: http://localhost:{PORT}/')
    print(f'Data file: {DATA_FILE}')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down...')
        server.shutdown()


if __name__ == '__main__':
    main()
