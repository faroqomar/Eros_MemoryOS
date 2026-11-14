#!/usr/bin/env python3
"""Loopback-only MemoryOS design lab and local feedback store."""
import argparse
import json
import math
import os
from pathlib import Path
import re
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, unquote

ROOT = Path(__file__).resolve().parent
STORE = ROOT / 'reviews' / 'feedback.json'
LOCK = threading.RLock()
VARIANTS = {'simple', 'atlas', 'almanac', 'circles', 'cabinet', 'focus', 'reference'}


def read_store():
    if not STORE.exists():
        return {'schemaVersion': 1, 'annotations': []}
    return json.loads(STORE.read_text())


def validate(item):
    if not isinstance(item, dict):
        raise ValueError('Invalid annotation')
    out = {}
    for key, limit in [('id', 100), ('variant', 30), ('screen', 100), ('detail', 100),
                       ('language', 5), ('kind', 20), ('category', 100), ('note', 6000),
                       ('label', 300), ('anchor', 150), ('createdAt', 50), ('updatedAt', 50)]:
        value = item.get(key, '')
        if not isinstance(value, str) or len(value) > limit:
            raise ValueError('Invalid ' + key)
        out[key] = value
    if not re.fullmatch(r'[a-zA-Z0-9_-]{1,100}', out['id']):
        raise ValueError('Invalid annotation ID')
    if out['variant'] not in VARIANTS or out['kind'] not in {'like', 'dislike', 'note'}:
        raise ValueError('Invalid annotation type')
    if out['language'] not in {'en', 'ar'}:
        raise ValueError('Invalid language')
    rect = item.get('rect')
    if not isinstance(rect, dict):
        raise ValueError('Missing region')
    out['rect'] = {}
    for key in ['x', 'y', 'w', 'h']:
        v = rect.get(key)
        if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or not 0 <= v <= 1:
            raise ValueError('Invalid region')
        out['rect'][key] = round(v, 6)
    if out['rect']['w'] <= 0 or out['rect']['h'] <= 0 or out['rect']['x'] + out['rect']['w'] > 1.001 or out['rect']['y'] + out['rect']['h'] > 1.001:
        raise ValueError('Region is outside the design')
    return out


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, fmt, *args):
        if self.path.startswith('/api/') or args and str(args[1]) not in {'200', '304'}:
            super().log_message(fmt, *args)

    def end_headers(self):
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def respond(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        route = urlparse(self.path).path
        if route == '/api/feedback':
            with LOCK:
                self.respond(read_store())
            return
        if route.startswith('/api/'):
            self.respond({'error': 'Unknown endpoint'}, 404)
            return
        resolved = (ROOT / unquote(route).lstrip('/')).resolve()
        if not resolved.is_relative_to(ROOT) or any(p.startswith('.') for p in Path(route).parts) or route.startswith('/reviews'):
            self.send_error(403)
            return
        if resolved.is_dir() and route not in {'/', ''}:
            self.send_error(403)
            return
        super().do_GET()

    def do_POST(self):
        route = urlparse(self.path).path
        if route not in {'/api/feedback', '/api/import'}:
            self.respond({'error': 'Unknown endpoint'}, 404)
            return
        origin = self.headers.get('Origin')
        if origin and urlparse(origin).netloc != self.headers.get('Host'):
            self.respond({'error': 'Cross-origin writes are disabled'}, 403)
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 2_000_000:
                raise ValueError('Invalid request size')
            data = json.loads(self.rfile.read(length))
            with LOCK:
                current = read_store()
                items = {x['id']: x for x in current['annotations']}
                if route == '/api/import':
                    if data.get('schemaVersion') != 1 or not isinstance(data.get('annotations'), list) or len(data['annotations']) > 5000:
                        raise ValueError('Use a MemoryOS lab JSON export')
                    validated = [validate(x) for x in data['annotations']]
                    for item in validated:
                        items[item['id']] = item
                elif data.get('operation') == 'delete':
                    items.pop(str(data.get('id')), None)
                elif data.get('operation') == 'upsert':
                    item = validate(data.get('annotation'))
                    items[item['id']] = item
                else:
                    raise ValueError('Invalid feedback operation')
                current['annotations'] = list(items.values())
                STORE.parent.mkdir(exist_ok=True)
                temp = STORE.with_suffix('.tmp')
                with temp.open('w') as f:
                    json.dump(current, f, ensure_ascii=False, indent=2)
                    f.flush()
                    os.fsync(f.fileno())
                temp.replace(STORE)
                self.respond(current)
        except (ValueError, TypeError, AttributeError, KeyError) as exc:
            self.respond({'error': str(exc)}, 400)
        except OSError:
            self.respond({'error': 'Could not write feedback to disk. Export a copy and try again.'}, 500)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5488)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'MemoryOS design lab: http://127.0.0.1:{args.port}', flush=True)
    print(f'Feedback stays local: {STORE}', flush=True)
    server.serve_forever()
