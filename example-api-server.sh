#!/bin/bash

# Example API Server for Reex App
# This demonstrates the expected format for task monitoring and result upload endpoints

PORT=8080

echo "Starting Reex API Example Server on port $PORT"
echo "Task Monitor URL: http://localhost:$PORT/tasks"
echo "Upload Record URL: http://localhost:$PORT/upload"

# Create a simple HTTP server using Python
python3 - <<'EOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime

# Sample tasks that the app will fetch
tasks = [
    {
        "id": "task-001",
        "name": "hello",
        "params": {
            "name": "World"
        }
    }
]

class ReexAPIHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/tasks':
            # Return the task list
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(tasks).encode())
            print(f"[{datetime.now()}] Sent tasks: {tasks}")
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/upload':
            # Receive execution results
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode())
                print(f"\n[{datetime.now()}] Received execution result:")
                print(f"  Task ID: {data.get('id')}")
                print(f"  Exit Code: {data.get('exitCode')}")
                print(f"  Timestamp: {data.get('timestamp')}")
                print(f"  Output: {data.get('output')[:100]}...")
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                response = {"status": "success", "message": "Result uploaded"}
                self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                print(f"Error processing upload: {e}")
                self.send_response(400)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress default logging

server = HTTPServer(('localhost', 8080), ReexAPIHandler)
print("\nServer started! Press Ctrl+C to stop.")
server.serve_forever()
EOF
