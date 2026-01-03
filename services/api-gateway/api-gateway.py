from flask import Flask, jsonify, request
import requests
import itertools
import time
import logging
import os

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [API-GATEWAY] %(message)s"
)

class LoadBalancer:
    def __init__(self, backends):
        self.backends = itertools.cycle(backends)
        self.backend_list = backends
    
    def get_backend(self):
        # In a real scenario, we might want to skip unhealthy backends here 
        # but for simplicity we'll just return next and let the caller handle errors
        # or use health_check to update the cycle.
        backend = next(self.backends)
        logging.info(f"Routing request to: {backend}")
        return backend

    def health_check(self):
        healthy = []
        for backend in self.backend_list:
            try:
                response = requests.get(f"{backend}/health", timeout=1)
                if response.status_code == 200:
                    healthy.append(backend)
            except:
                pass
        
        # If we have healthy backends, update the cycle
        if healthy:
            logging.info(f"Healthy backends: {healthy}")
            self.backends = itertools.cycle(healthy)
        else:
            logging.warning("No healthy backends found! Resetting to all backends.")
            self.backends = itertools.cycle(self.backend_list)
        
        return healthy

app = Flask(__name__)

# =========================
# STATIC SERVICE BACKENDS
# (Later can be replaced with discovery lookups)
# ========================
# Allow overriding product service backends via env var
product_backends_str = os.getenv("PRODUCT_SERVICE_URLS")
if product_backends_str:
    product_backends = product_backends_str.split(",")
else:
    product_backends = [
        "http://10.0.0.30:5000",
        "http://10.0.0.31:5000",
        "http://10.0.0.32:5000"
    ]

product_lb = LoadBalancer(product_backends)

ORDER_SERVICE = os.getenv("ORDER_SERVICE", "http://10.0.0.40:5000")

# =========================
# SERVICE REGISTRY CONFIG
# =========================
SERVICE_REGISTRY = os.getenv("SERVICE_REGISTRY", "http://10.0.0.70:8500")
SERVICE_NAME = "api-gateway"
SERVICE_IP = os.getenv("SERVICE_IP", "10.0.0.20")
SERVICE_PORT = 3000

# =========================
# STARTUP REGISTRATION
# =========================
def register_with_registry():
    payload = {
        "name": SERVICE_NAME,
        "ip": SERVICE_IP,
        "port": SERVICE_PORT
    }

    for attempt in range(5):
        try:
            r = requests.post(
                f"{SERVICE_REGISTRY}/register",
                json=payload,
                timeout=2
            )
            if r.status_code == 200:
                print(f"✅ Registered {SERVICE_NAME} with service registry")
                return
        except Exception as e:
            print(f"⏳ Registry not ready (attempt {attempt + 1}/5): {e}")
            time.sleep(2)

    print("❌ Failed to register api-gateway with service registry")

# =========================
# HEALTH ENDPOINT
# =========================
@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "api-gateway"})

# =========================
# PRODUCT ROUTES
# =========================
@app.route('/api/products', methods=['GET'])
def get_products():
    try:
        backend = product_lb.get_backend()
        response = requests.get(f"{backend}/products", timeout=2)
        return jsonify(response.json()), response.status_code
    except requests.exceptions.Timeout:
        return jsonify({"error": "Backend timeout"}), 504
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "Backend connection failed"}), 502
    except ValueError: # JSONDecodeError
        logging.error(f"Invalid JSON from backend: {response.text}")
        return jsonify({"error": f"Invalid response from backend: {response.text[:200]}"}), 500
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        return jsonify({"error": str(e)}), 503

@app.route('/api/products/<id>', methods=['GET'])
def get_product(id):
    try:
        backend = product_lb.get_backend()
        response = requests.get(f"{backend}/products/{id}", timeout=2)
        return jsonify(response.json()), response.status_code
    except requests.exceptions.Timeout:
        return jsonify({"error": "Backend timeout"}), 504
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "Backend connection failed"}), 502
    except ValueError: # JSONDecodeError
        logging.error(f"Invalid JSON from backend: {response.text}")
        return jsonify({"error": f"Invalid response from backend: {response.text[:200]}"}), 500
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        return jsonify({"error": str(e)}), 503

# =========================
# ORDER ROUTES
# =========================
@app.route('/api/orders', methods=['POST'])
def create_order():
    try:
        response = requests.post(
            f"{ORDER_SERVICE}/orders",
            json=request.json
        )
        return jsonify(response.json()), response.status_code
    except requests.exceptions.Timeout:
        return jsonify({"error": "Backend timeout"}), 504
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "Backend connection failed"}), 502
    except ValueError: # JSONDecodeError
        logging.error(f"Invalid JSON from backend: {response.text}")
        return jsonify({"error": "Invalid response from backend"}), 500
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        return jsonify({"error": str(e)}), 503

# =========================
# MAIN
# =========================
if __name__ == '__main__':
    register_with_registry()
    app.run(host='0.0.0.0', port=3000)
