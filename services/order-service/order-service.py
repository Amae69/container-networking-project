from flask import Flask, jsonify, request
import psycopg2
from datetime import datetime
import json
import os

app = Flask(__name__)

# Database connection
def get_db():
    db_host = os.environ.get('DB_HOST', '10.0.0.60')
    return psycopg2.connect(
        host=db_host,
        database='orders',
        user='postgres',
        password='postgres'
    )

# Initialize database
def init_db():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute('''
            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                customer_id VARCHAR(100),
                product_id VARCHAR(100),
                quantity INTEGER,
                total_price DECIMAL(10, 2),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        cur.close()
        conn.close()
        print("Database initialized successfully")
    except Exception as e:
        print(f"Database initialization failed: {e}")

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "order-service"})

@app.route('/orders', methods=['POST'])
def create_order():
    data = request.json
    
    try:
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute(
            '''INSERT INTO orders (customer_id, product_id, quantity, total_price)
               VALUES (%s, %s, %s, %s) RETURNING id''',
            (data['customer_id'], data['product_id'], 
             data['quantity'], data['total_price'])
        )
        
        order_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({"order_id": order_id, "status": "created"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/orders/<order_id>', methods=['GET'])
def get_order(order_id):
    try:
        conn = get_db()
        cur = conn.cursor()
        
        cur.execute('SELECT * FROM orders WHERE id = %s', (order_id,))
        order = cur.fetchone()
        
        cur.close()
        conn.close()
        
        if not order:
            return jsonify({"error": "Order not found"}), 404
        
        return jsonify({
            "id": order[0],
            "customer_id": order[1],
            "product_id": order[2],
            "quantity": order[3],
            "total_price": float(order[4]),
            "created_at": order[5].isoformat()
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Try to init DB on startup
    init_db()
    app.run(host='0.0.0.0', port=5000)
