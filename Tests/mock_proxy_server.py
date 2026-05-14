"""
Mock DeepLLMProxy HTTP server - 用于测试 TProxyLLMClient
模拟 /health 和 /v1/chat/completions 端点
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import threading
import time


class MockProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length).decode('utf-8')
        req = json.loads(body)

        if self.path == '/v1/chat/completions':
            tier = req.get('model', 'balanced')
            stream = req.get('stream', False)
            user_msg = ''
            for m in req.get('messages', []):
                if m.get('role') == 'user':
                    user_msg = m.get('content', '')

            if stream:
                # SSE response
                self.send_response(200)
                self.send_header('Content-Type', 'text/event-stream')
                self.end_headers()
                chunks = ['Hello ', 'from ', 'mock ', 'proxy ', f'[{tier}]']
                for c in chunks:
                    data = {
                        'choices': [{'delta': {'content': c}, 'index': 0}]
                    }
                    self.wfile.write(f'data: {json.dumps(data)}\n\n'.encode())
                    self.wfile.flush()
                    time.sleep(0.05)
                self.wfile.write(b'data: [DONE]\n\n')
            else:
                # Non-stream response
                reply = f'Mock reply [tier={tier}]: you said "{user_msg}"'
                resp = {
                    'id': 'mock-001',
                    'object': 'chat.completion',
                    'model': f'mock-{tier}-model',
                    'choices': [{
                        'index': 0,
                        'message': {'role': 'assistant', 'content': reply},
                        'finish_reason': 'stop'
                    }],
                    'usage': {
                        'prompt_tokens': 10,
                        'completion_tokens': 15,
                        'total_tokens': 25
                    }
                }
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(resp).encode('utf-8'))

        elif self.path == '/v1/images/generations':
            prompt = req.get('prompt', '')
            resp = {
                'model': 'mock-image-model',
                'data': [{
                    'url': 'https://example.com/mock.png',
                    'b64_json': ''
                }]
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args):
        # Reduce noise
        print(f"[MockProxy] {fmt % args}")


def main():
    port = 8089
    server = HTTPServer(('127.0.0.1', port), MockProxyHandler)
    print(f"Mock proxy listening on http://127.0.0.1:{port}")
    print("Endpoints: /health, /v1/chat/completions, /v1/images/generations")
    server.serve_forever()


if __name__ == '__main__':
    main()
